"""Pure validation for the existing CarGOUI GitHub Release installer.

These helpers never access credentials, the network, or the filesystem. The ZIP
is inspected in memory and is never extracted, modified, or repackaged.
"""

from __future__ import annotations

import hashlib
import hmac
import io
import re
import stat
import zipfile
import zlib


class ValidationError(ValueError):
    """An input is unsuitable for an official CarGOUI release."""


STABLE_TAG = re.compile(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")
MANUAL_RELEASE_MESSAGE = (
    "CarGOUI 1.0.0 was already published manually; duplicate upload blocked."
)
MAX_ZIP_BYTES = 100 * 1024 * 1024
MAX_EXPANDED_BYTES = 200 * 1024 * 1024
MAX_MEMBER_BYTES = 20 * 1024 * 1024
MAX_MEMBERS = 5000
ADDON_ROOTS = {"CarGOUI", "CarGOUI_Data"}
FORBIDDEN_DIRECTORIES = {
    ".git", ".github", ".idea", ".vscode", "__pycache__", "node_modules",
    "test", "tests", "tool", "tools", "tmp", "temp", "temporary", "work",
    "build", "dist", "out", "output", "outputs", "artifact", "artifacts",
    "release", "releases", "source", "sources", "src", "docs", "coverage",
}
RUNTIME_MEDIA_SUFFIXES = {".tga", ".blp", ".png", ".jpg", ".jpeg", ".ogg", ".mp3", ".wav"}


def stable_version(tag):
    """Return X.Y.Z only for a canonical stable vX.Y.Z tag."""
    if not isinstance(tag, str) or STABLE_TAG.fullmatch(tag) is None:
        raise ValidationError("Only canonical stable vX.Y.Z release tags are supported.")
    return tag[1:]


def ensure_upload_allowed(version, run_attempt="1"):
    """Reject the manually published release and all rerun upload attempts."""
    if version == "1.0.0":
        raise ValidationError(MANUAL_RELEASE_MESSAGE)
    stable_version("v" + str(version))
    if str(run_attempt) != "1":
        raise ValidationError("Upload on a rerun is blocked; reconcile the original attempt first.")


def select_assets(release, version):
    """Select exactly the two complete assets from a published stable release."""
    stable_version("v" + str(version))
    if not isinstance(release, dict):
        raise ValidationError("The GitHub Release response is invalid.")
    if release.get("draft") is not False or release.get("prerelease") is not False:
        raise ValidationError("The GitHub Release must be published and stable.")
    if not release.get("published_at"):
        raise ValidationError("The GitHub Release has not been published.")
    if release.get("tag_name") != "v" + version:
        raise ValidationError("The GitHub Release tag does not match the requested version.")
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise ValidationError("The GitHub Release asset list is missing.")
    selected = []
    for suffix in ("zip", "sha256"):
        name = "CarGOUI-" + version + "." + suffix
        matches = [asset for asset in assets if isinstance(asset, dict) and asset.get("name") == name]
        if len(matches) != 1:
            raise ValidationError("Exactly one official " + suffix.upper() + " asset is required.")
        asset = matches[0]
        size = asset.get("size")
        if asset.get("state") != "uploaded" or type(size) is not int or size <= 0:
            raise ValidationError("The official " + suffix.upper() + " asset is incomplete or empty.")
        selected.append(asset)
    return tuple(selected)


def verify_checksum(zip_bytes, checksum_bytes, filename):
    """Match the exact ZIP bytes to one digest-only or sha256sum-format entry."""
    if not isinstance(checksum_bytes, bytes) or len(checksum_bytes) > 4096:
        raise ValidationError("The SHA256 asset is invalid or too large.")
    try:
        checksum_text = checksum_bytes.decode("ascii")
    except UnicodeDecodeError as exc:
        raise ValidationError("The SHA256 asset must contain ASCII text.") from exc
    # One terminal newline is normal. Additional lines, including blank entries,
    # are refused so there is no ambiguity about which digest is authoritative.
    if checksum_text.endswith("\r\n"):
        checksum_text = checksum_text[:-2]
    elif checksum_text.endswith("\n"):
        checksum_text = checksum_text[:-1]
    match = re.fullmatch(r"([0-9a-fA-F]{64})(?: [ *]([^\r\n]+))?", checksum_text)
    if match is None or (match.group(2) is not None and match.group(2) != filename):
        raise ValidationError("The SHA256 asset must contain one digest for the exact ZIP filename.")
    digest = hashlib.sha256(zip_bytes).hexdigest()
    if not hmac.compare_digest(digest, match.group(1).lower()):
        raise ValidationError("The official ZIP SHA256 checksum does not match.")
    return digest


def _path_parts(name, *, directory=False):
    """Require a portable, unambiguous relative ZIP or TOC path."""
    if not isinstance(name, str) or not name or not name.isascii():
        raise ValidationError("Archive paths must be nonempty ASCII relative paths.")
    if "\\" in name or any(ord(char) < 32 or ord(char) == 127 for char in name):
        raise ValidationError("Archive paths contain unsafe separators or control characters.")
    path = name[:-1] if directory and name.endswith("/") else name
    parts = path.split("/")
    for part in parts:
        if not part or part in {".", ".."} or part.endswith((".", " ")):
            raise ValidationError("Archive paths contain a noncanonical or traversing component.")
        if any(char in part for char in ':<>"|?*'):
            raise ValidationError("Archive paths contain a nonportable component.")
        stem = part.split(".", 1)[0].upper()
        if stem in {"CON", "PRN", "AUX", "NUL"} or re.fullmatch(r"(?:COM|LPT)[1-9]", stem):
            raise ValidationError("Archive paths contain a reserved device name.")
    return parts


def _toc_fields(data, root, version, file_names):
    try:
        lines = data.decode("utf-8-sig").splitlines()
    except UnicodeDecodeError as exc:
        raise ValidationError("Addon TOC files must be valid UTF-8.") from exc
    fields = {}
    entries = set()
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("##"):
            match = re.fullmatch(r"##\s*([^:]+):\s*(.*?)\s*", line)
            if match:
                key, value = match.group(1).strip().casefold(), match.group(2)
                if key in fields:
                    raise ValidationError("Addon TOC files must not contain duplicate metadata fields.")
                fields[key] = value
            continue
        if line.startswith("#"):
            continue
        entry = line.replace("\\", "/")
        parts = _path_parts(entry)
        if not entry.endswith(".lua"):
            raise ValidationError("Addon TOC entries must reference packaged Lua runtime files.")
        full_name = root + "/" + "/".join(parts)
        if full_name not in file_names or full_name in entries:
            raise ValidationError("Addon TOC entries are missing from the ZIP or duplicated.")
        entries.add(full_name)
    if fields.get("version") != version:
        raise ValidationError("Both addon TOC versions must match the GitHub Release version.")
    interface = fields.get("interface", "")
    if re.fullmatch(r"[1-9][0-9]{4,5}", interface) is None:
        raise ValidationError("Each addon TOC must declare one canonical numeric Retail Interface.")
    if not entries:
        raise ValidationError("Each addon TOC must declare runtime files.")
    if root == "CarGOUI_Data" and (
        fields.get("dependencies") != "CarGOUI" or fields.get("loadondemand") != "1"
    ):
        raise ValidationError("The data addon must load on demand and depend on CarGOUI.")
    return int(interface), entries


def _allowed_extra_file(name):
    parts = name.split("/")
    root, basename = parts[0], parts[-1]
    if root != "CarGOUI":
        return False
    if len(parts) == 2:
        return basename in {"README.md", "NOTICE.md", "CHANGELOG.md"} or (
            basename.upper().startswith(("LICENSE", "COPYING"))
            and ("." not in basename or basename.rsplit(".", 1)[-1].lower() in {"md", "txt"})
        )
    if parts[1] == "Libs":
        return name == "CarGOUI/Libs/THIRD_PARTY_NOTICES.md" or (
            basename.upper().startswith(("LICENSE", "COPYING"))
            and ("." not in basename or basename.rsplit(".", 1)[-1].lower() in {"md", "txt"})
        )
    if parts[1] == "Media":
        return (
            "." in basename and "." + basename.rsplit(".", 1)[-1].lower() in RUNTIME_MEDIA_SUFFIXES
        ) or basename in {"LICENSE.txt", "LICENSE.md", "COPYING", "COPYING.txt"}
    return False


def inspect_zip(zip_bytes, version):
    """Validate the untouched installer and infer its target from both TOCs."""
    stable_version("v" + str(version))
    if not isinstance(zip_bytes, bytes) or not zip_bytes or len(zip_bytes) > MAX_ZIP_BYTES:
        raise ValidationError("The official ZIP is empty or exceeds the size limit.")
    try:
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as archive:
            members = archive.infolist()
            if not members or len(members) > MAX_MEMBERS:
                raise ValidationError("The official ZIP has an invalid number of entries.")
            if sum(member.file_size for member in members) > MAX_EXPANDED_BYTES:
                raise ValidationError("The expanded ZIP exceeds the size limit.")
            seen_paths = set()
            spelling = {}
            roots = set()
            file_names = set()
            directory_names = set()
            toc_bytes = {}
            for member in members:
                # ZipInfo truncates filenames at NUL; inspect its original value.
                if member.orig_filename != member.filename:
                    raise ValidationError("The ZIP contains a truncated or ambiguous filename.")
                parts = _path_parts(member.filename, directory=member.is_dir())
                roots.add(parts[0])
                if parts[0] not in ADDON_ROOTS or (not member.is_dir() and len(parts) < 2):
                    raise ValidationError("The ZIP must contain only CarGOUI and CarGOUI_Data addon roots.")
                if any(part.startswith(".") or part.casefold() in FORBIDDEN_DIRECTORIES for part in parts):
                    raise ValidationError("The ZIP contains a hidden or development path.")
                normalized = "/".join(parts)
                key = normalized.casefold()
                if key in seen_paths:
                    raise ValidationError("The ZIP contains duplicate or case-colliding entries.")
                seen_paths.add(key)
                # Check implicit directories too, including differently cased
                # parent names that do not appear as explicit ZIP entries.
                for index in range(1, len(parts) + 1):
                    prefix = "/".join(parts[:index])
                    previous = spelling.setdefault(prefix.casefold(), prefix)
                    if previous != prefix:
                        raise ValidationError("The ZIP contains case-colliding directory paths.")
                mode = member.external_attr >> 16
                kind = stat.S_IFMT(mode)
                expected_kind = stat.S_IFDIR if member.is_dir() else stat.S_IFREG
                if kind not in {0, expected_kind}:
                    raise ValidationError("The ZIP contains a symbolic link or special filesystem entry.")
                if member.flag_bits & (1 | 0x40):
                    raise ValidationError("Encrypted ZIP entries are not supported.")
                if member.compress_type not in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED}:
                    raise ValidationError("The ZIP uses an unsupported compression method.")
                if member.file_size > MAX_MEMBER_BYTES:
                    raise ValidationError("A ZIP entry exceeds the expanded size limit.")
                if member.is_dir():
                    if member.file_size:
                        raise ValidationError("ZIP directory entries must be empty.")
                    directory_names.add(normalized)
                    continue
                file_names.add(normalized)
                # Reading every file checks its local header and CRC, and the
                # declared limits above bound decompression before this read.
                data = archive.read(member)
                if len(data) != member.file_size:
                    raise ValidationError("The ZIP entry size does not match its directory record.")
                if normalized in {"CarGOUI/CarGOUI.toc", "CarGOUI_Data/CarGOUI_Data.toc"}:
                    toc_bytes[normalized] = data
            if roots != ADDON_ROOTS:
                raise ValidationError("The ZIP must contain both CarGOUI and CarGOUI_Data addon roots.")
            if any(not any(name.startswith(directory + "/") for name in file_names) for directory in directory_names):
                raise ValidationError("The ZIP contains an empty directory outside the runtime installer.")
            for name in file_names:
                if any("/".join(name.split("/")[:index]) in file_names for index in range(1, len(name.split("/")))):
                    raise ValidationError("The ZIP contains a file that is also used as a directory.")
            runtime_files = set()
            interfaces = set()
            for root in sorted(ADDON_ROOTS):
                toc_name = root + "/" + root + ".toc"
                if toc_name not in toc_bytes:
                    raise ValidationError("The ZIP must contain both addon TOC files at the expected paths.")
                interface, entries = _toc_fields(toc_bytes[toc_name], root, version, file_names)
                interfaces.add(interface)
                runtime_files.update(entries)
                runtime_files.add(toc_name)
            if len(interfaces) != 1:
                raise ValidationError("Both addon TOC files must target the same Retail Interface.")
            if any(name not in runtime_files and not _allowed_extra_file(name) for name in file_names):
                raise ValidationError("The ZIP contains files outside the runtime installer allowlist.")
            interface = interfaces.pop()
            game_version = f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}"
            return {"interface": interface, "game_version": game_version, "file_count": len(file_names)}
    except ValidationError:
        raise
    except (zipfile.BadZipFile, zipfile.LargeZipFile, RuntimeError, OSError, EOFError, ValueError, zlib.error) as exc:
        raise ValidationError("The official ZIP is malformed or failed its integrity check.") from exc


def build_metadata(version, body, game_version_id):
    """Create the official author-upload metadata without modifying release notes."""
    stable_version("v" + str(version))
    if type(game_version_id) is not int or game_version_id <= 0:
        raise ValidationError("The resolved CurseForge game version ID must be a positive integer.")
    if body is not None and not isinstance(body, str):
        raise ValidationError("The GitHub Release body must be text.")
    return {
        "changelog": body if body and body.strip() else "Official CarGOUI " + version + " release.",
        "changelogType": "markdown",
        "displayName": "CarGOUI " + version,
        "gameVersions": [game_version_id],
        "releaseType": "release",
    }
