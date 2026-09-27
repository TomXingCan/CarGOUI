"""Build a runtime-only two-addon installer and test its extracted code.

python tools/package.py --output /path/to/deliverables [--git /path/to/git]
Requires the same existing Lua 5.1/lupa runtime as tests/run_tests.py.
No network access, dependency installation, game-file writes or cleanup deletes.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys
import zipfile


def install_files(files):
    prefix = "Modules/CarGOUI_Data/"
    result = {}
    for toc, parent in (("CarGOUI.toc", ""), (prefix + "CarGOUI_Data.toc", prefix)):
        lines = files[toc].decode("utf-8-sig").splitlines()
        entries = [line.strip().replace("\\", "/") for line in lines if line.strip() and not line.startswith("#")]
        assert len(entries) == len(set(entries)), "Duplicate TOC entries"
        assert all(parent + entry in files for entry in entries), "Missing TOC source"
        if parent:
            assert "## LoadOnDemand: 1" in lines and "## Dependencies: CarGOUI" in lines
        else:
            assert not any("Classes/" in entry for entry in entries), "Core must not list class files"
        installed_root = "CarGOUI_Data/" if parent else "CarGOUI/"
        result[installed_root + Path(toc).name] = files[toc]
        for entry in entries:
            assert entry.endswith(".lua") and ".." not in Path(entry).parts, "Unexpected runtime entry"
            result[installed_root + entry] = files[parent + entry]
    for name in ("emblem.tga", "wordmark.tga", "wordmark-mask.tga", "sweep.tga"):
        path = "Media/Branding/" + name
        result["CarGOUI/" + path] = files[path]
    result["CarGOUI/README.md"] = files["docs/USER_README.md"]
    result["CarGOUI/NOTICE.md"] = files["NOTICE.md"]
    result["CarGOUI/CHANGELOG.md"] = files["CHANGELOG.md"]
    # Preserve any existing license documents without inventing a new license.
    for path, data in files.items():
        if "/" not in path and Path(path).name.upper().startswith(("LICENSE", "COPYING")):
            result["CarGOUI/" + path] = data
    assert {path.split("/")[0] for path in result} == {"CarGOUI", "CarGOUI_Data"}
    assert not any(part in ("tests", "tools", "source", ".git", "work")
                   for path in result for part in Path(path).parts)
    assert all(not path.endswith((".py", ".zip", ".patch", ".gitkeep")) for path in result)
    return result


def write_archive(files, target):
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path, data in sorted(files.items()):
            info = zipfile.ZipInfo(path, date_time=(2026, 9, 26, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(files)
        for path, data in files.items():
            assert archive.read(path) == data
    return hashlib.sha256(target.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--git", default="git")
    args = parser.parse_args()
    # Child tests run inside the extracted addon, so their paths must not be
    # reinterpreted relative to that new working directory.
    args.output = args.output.resolve()
    repo = Path(__file__).resolve().parent.parent
    command = [args.git, "-c", "safe.directory=" + repo.as_posix(), "-C", str(repo)]
    def git(*arguments):
        return subprocess.check_output(command + list(arguments))
    assert not git("status", "--porcelain").strip(), "Commit changes before packaging"
    commit = git("rev-parse", "HEAD").decode().strip()
    tree = git("rev-parse", "HEAD^{tree}").decode().strip()
    files = {path: git("show", "HEAD:" + path) for path in git("ls-tree", "-r", "--name-only", "HEAD").decode().splitlines()}
    version = next(line.split(":", 1)[1].strip() for line in files["CarGOUI.toc"].decode().splitlines() if line.startswith("## Version:"))
    args.output.mkdir(parents=True, exist_ok=True)
    data_version = next(line.split(":", 1)[1].strip() for line in files["Modules/CarGOUI_Data/CarGOUI_Data.toc"].decode().splitlines() if line.startswith("## Version:"))
    assert data_version == version
    assert ('addon.version = "' + version + '"') in files["Core/Addon.lua"].decode()
    assert version in files["CHANGELOG.md"].decode()
    target = args.output / ("CarGOUI-" + version + ".zip")
    installed = install_files(files)
    digest = write_archive(installed, target)
    extraction = args.output / ("package-check-" + digest[:12])
    assert not extraction.exists(), "Verification directory already exists; choose a new output directory"
    extraction.mkdir()
    with zipfile.ZipFile(target) as archive:
        archive.extractall(extraction)
    lines = ["Version: " + version, "Commit: " + commit, "Tree: " + tree,
             "Archive: " + target.name, "SHA256: " + digest,
             "Verification: repository test tools against extracted final runtime-only installer.",
             "Native WoW C_EncodingUtil/client combat/visual/performance acceptance: not executed."]
    failed = False
    tests = [repo / "tests/run_tests.py"] + sorted((repo / "tests").glob("check_*_static.py"))
    for test in tests:
        result = subprocess.run([sys.executable, str(test), "--addon-root", str(extraction / "CarGOUI")],
                                cwd=extraction / "CarGOUI", env=os.environ,
                                capture_output=True, text=True, encoding="utf-8")
        lines += ["\n" + test.name + ": exit " + str(result.returncode), result.stdout, result.stderr]
        failed = failed or result.returncode != 0
    target.with_suffix(".tests.txt").write_text("\n".join(lines), encoding="utf-8")
    target.with_suffix(".sha256").write_text(digest + "  " + target.name + "\n", encoding="ascii")
    print(json.dumps({"archive": str(target), "sha256": digest, "files": len(installed), "tests_passed": not failed}))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
