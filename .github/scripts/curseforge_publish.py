"""Publish the exact GitHub Release installer, or perform read-only validation.

Only the GitHub runner receives credentials. No response bodies, headers, tokens,
or exception representations are logged. Authenticated redirects are forbidden.
"""
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

from curseforge_validation import (
    ValidationError, stable_version, ensure_upload_allowed, select_assets,
    verify_checksum, inspect_zip, build_metadata,
)

REPOSITORY = "TomXingCan/CarGOUI"
PROJECT_ID = "1712424"
CF_ORIGIN = "https://wow.curseforge.com"
GH_ORIGIN = "https://api.github.com"
MAX_BYTES = 64 * 1024 * 1024


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class AssetRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urllib.parse.urlsplit(newurl)
        if target.scheme != "https" or target.hostname not in {
            "github.com", "release-assets.githubusercontent.com",
            "objects.githubusercontent.com",
        } or target.username or target.password:
            raise ValidationError("Release asset redirect destination rejected.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Client:
    def __init__(self, cf_token, github_token=""):
        if not cf_token or not cf_token.strip():
            raise ValidationError("CURSEFORGE_API_TOKEN is missing.")
        self._cf_token = cf_token
        self._github_token = github_token
        self._opener = urllib.request.build_opener(NoRedirect)
        self._asset_opener = urllib.request.build_opener(AssetRedirect)
        self.upload_attempts = 0

    def _request(self, url, *, data=None, content_type=None, asset=False):
        headers = {"User-Agent": "CarGOUI-release-publisher", "Accept": "application/json"}
        origin = urllib.parse.urlsplit(url)
        if origin.scheme != "https" or origin.username or origin.password:
            raise ValidationError("HTTP destination rejected.")
        if asset:
            if not url.startswith(f"https://github.com/{REPOSITORY}/releases/download/"):
                raise ValidationError("Release asset URL rejected.")
            headers["Accept"] = "application/octet-stream"
        elif origin.netloc == "wow.curseforge.com":
            headers["X-Api-Token"] = self._cf_token
        elif origin.netloc == "api.github.com":
            if self._github_token:
                headers["Authorization"] = "Bearer " + self._github_token
            headers["X-GitHub-Api-Version"] = "2022-11-28"
        else:
            raise ValidationError("HTTP destination rejected.")
        if content_type:
            headers["Content-Type"] = content_type
        request = urllib.request.Request(url, data=data, headers=headers,
                                         method="POST" if data is not None else "GET")
        try:
            # Deliberately one attempt, with no retry middleware or POST redirects.
            opener = self._asset_opener if asset else self._opener
            with opener.open(request, timeout=60) as response:
                body = response.read(MAX_BYTES + 1)
                if len(body) > MAX_BYTES:
                    raise ValidationError("HTTP response exceeded the size limit.")
                return body
        except urllib.error.HTTPError as exc:
            raise ValidationError(f"HTTP request failed (status {exc.code}); no retry performed.") from None
        except (urllib.error.URLError, TimeoutError, OSError):
            raise ValidationError("HTTP request failed; outcome may be unknown. No retry performed.") from None

    def get_json(self, url):
        payload = self._request(url)
        try:
            return json.loads(payload)
        except (ValueError, UnicodeError):
            raise ValidationError("API returned invalid JSON.") from None

    def asset(self, record, tag):
        expected = f"https://github.com/{REPOSITORY}/releases/download/{tag}/{record['name']}"
        if record.get("browser_download_url") != expected:
            raise ValidationError("Release asset URL does not match its tag and filename.")
        payload = self._request(expected, asset=True)
        if len(payload) != record["size"]:
            raise ValidationError("Release asset size does not match GitHub metadata.")
        digest = record.get("digest")
        if digest and digest != "sha256:" + hashlib.sha256(payload).hexdigest():
            raise ValidationError("Release asset digest does not match GitHub metadata.")
        return payload

    def upload_once(self, version, run_attempt, archive, metadata):
        ensure_upload_allowed(version, run_attempt)
        if self.upload_attempts:
            raise ValidationError("A real upload was already attempted; retry blocked.")
        boundary = "CarGOUI" + uuid.uuid4().hex
        filename = f"CarGOUI-{version}.zip"
        body = (
            f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
            'Content-Type: application/json\r\n\r\n'
        ).encode() + json.dumps(metadata, ensure_ascii=False).encode("utf-8")
        body += (
            f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            'Content-Type: application/zip\r\n\r\n'
        ).encode() + archive + f"\r\n--{boundary}--\r\n".encode()
        self.upload_attempts += 1  # Set before I/O, including timeout/ambiguous outcomes.
        response = self._request(
            f"{CF_ORIGIN}/api/projects/{PROJECT_ID}/upload-file", data=body,
            content_type=f"multipart/form-data; boundary={boundary}",
        )
        try:
            file_id = json.loads(response)["id"]
            if type(file_id) is not int or file_id <= 0:
                raise ValueError
            return file_id
        except (ValueError, KeyError, TypeError):
            raise ValidationError("Upload response could not be confirmed. Do not retry; inspect CurseForge.") from None


def records(payload, label):
    if isinstance(payload, list):
        result = payload
    elif isinstance(payload, dict):
        result = payload.get("data", payload.get(label))
    else:
        result = None
    if not isinstance(result, list) or not all(isinstance(item, dict) for item in result):
        raise ValidationError(f"Unexpected {label} API schema; manual investigation required.")
    return result


def validate_project_id(project_id):
    if project_id != PROJECT_ID:
        raise ValidationError("CURSEFORGE_PROJECT_ID must equal 1712424.")


def confirm_project(payload):
    matches = [item for item in records(payload, "projects") if str(item.get("id")) == PROJECT_ID]
    if len(matches) != 1 or matches[0].get("name") != "CarGOUI" or matches[0].get("slug") != "cargoui":
        raise ValidationError("CurseForge project 1712424 could not be uniquely confirmed as CarGOUI (cargoui).")
    return matches[0]


def resolve_game_version(versions_payload, types_payload, target):
    types = records(types_payload, "gameVersionTypes")
    retail = [item for item in types if item.get("name") == "WoW Retail"
              or item.get("slug") in {"wow-retail", "wow_retail"}]
    if len(retail) != 1 or type(retail[0].get("id")) is not int:
        raise ValidationError("Could not uniquely identify the WoW Retail game version type.")
    matches = [item for item in records(versions_payload, "versions")
               if item.get("name") == target and item.get("gameVersionTypeID") == retail[0]["id"]]
    if len(matches) != 1 or type(matches[0].get("id")) is not int or matches[0]["id"] <= 0:
        raise ValidationError("No unique CurseForge Retail game version matches the installer TOC.")
    return matches[0]["id"], retail[0]["id"]


def file_snapshot(payload):
    files = records(payload, "files")
    if any(type(item.get("id")) is not int or item["id"] <= 0 for item in files):
        raise ValidationError("Unexpected CurseForge file identifiers.")
    # Refuse paginated/incomplete listings rather than claiming no duplicates.
    if isinstance(payload, dict) and "pagination" in payload:
        pagination = payload["pagination"]
        if not isinstance(pagination, dict) or pagination.get("totalCount") != len(files):
            raise ValidationError("CurseForge file listing is incomplete.")
    return files


def reject_existing_file(files, version):
    filename = f"CarGOUI-{version}.zip"
    display_name = f"CarGOUI {version}"
    for item in files:
        if item.get("fileName") == filename or item.get("displayName") == display_name:
            raise ValidationError("This version already exists on CurseForge; duplicate upload blocked.")
        if not isinstance(item.get("fileName"), str):
            raise ValidationError("CurseForge file names could not be checked for duplicates.")


def reject_previous_publish(client, tag, run_id):
    # Public GET uses no additional Actions permission. Prior attempts block even
    # when their outcome was ambiguous; neither reruns nor new dispatches retry POST.
    title = f"CurseForge {tag} (publish)"
    for page in range(1, 11):
        payload = client.get_json(
            f"{GH_ORIGIN}/repos/{REPOSITORY}/actions/workflows/publish-curseforge.yml/runs?per_page=100&page={page}"
        )
        runs = payload.get("workflow_runs") if isinstance(payload, dict) else None
        if not isinstance(runs, list):
            raise ValidationError("Could not verify prior publish attempts.")
        for run in runs:
            if str(run.get("id")) != run_id and run.get("display_title") == title:
                raise ValidationError("A publish run already exists for this tag; inspect its outcome before any manual recovery.")
        if len(runs) < 100:
            return
    raise ValidationError("Publish history exceeds the safe lookup limit; manual investigation required.")


def execute(client, *, tag, mode, project_id, run_attempt="1", run_id="", report=None):
    report = report if report is not None else {}
    if mode not in {"validate", "publish"}:
        raise ValidationError("Mode must be validate or publish.")
    version = stable_version(tag)
    validate_project_id(project_id)
    report.update(mode=mode, tag=tag, version=version, project_id=int(PROJECT_ID), secret_present=True)
    if mode == "publish":
        ensure_upload_allowed(version, run_attempt)
    # Exercise the permanent guard even in validation mode without invoking POST.
    try:
        ensure_upload_allowed("1.0.0")
    except ValidationError:
        report["duplicate_guard_1_0_0"] = "passed"
    else:
        raise ValidationError("The permanent 1.0.0 duplicate guard failed.")
    if version == "1.0.0":
        report["upload_block_reason"] = "CarGOUI 1.0.0 was already published manually; duplicate upload blocked."

    release = client.get_json(f"{GH_ORIGIN}/repos/{REPOSITORY}/releases/tags/{tag}")
    zip_asset, checksum_asset = select_assets(release, version)
    archive = client.asset(zip_asset, tag)
    checksum = client.asset(checksum_asset, tag)
    digest = verify_checksum(archive, checksum, zip_asset["name"])
    report["sha256"] = digest
    report["sha256_check"] = "passed"
    package = inspect_zip(archive, version)
    report.update(zip_structure="passed", **package)

    versions = client.get_json(f"{CF_ORIGIN}/api/game/versions")
    report["token_authentication"] = "passed"
    types = client.get_json(f"{CF_ORIGIN}/api/game/version-types")
    version_id, type_id = resolve_game_version(versions, types, package["game_version"])
    report.update(game_version_id=version_id, game_version_type_id=type_id)
    confirm_project(client.get_json(f"{CF_ORIGIN}/api/projects"))
    report["curseforge_project"] = "CarGOUI (cargoui)"
    files_url = f"{CF_ORIGIN}/api/projects/{PROJECT_ID}/files"
    before = file_snapshot(client.get_json(files_url))
    report["curseforge_files_before"] = sorted(item["id"] for item in before)
    metadata = build_metadata(version, release.get("body"), version_id)
    json.loads(json.dumps(metadata, ensure_ascii=False))
    report["metadata_json"] = "valid"
    if mode == "validate":
        after = file_snapshot(client.get_json(files_url))
        report["curseforge_files_after"] = sorted(item["id"] for item in after)
        if report["curseforge_files_before"] != report["curseforge_files_after"]:
            raise ValidationError("CurseForge file list changed during validation; investigate external activity.")
        report.update(real_upload_post=False, new_curseforge_files=False, result="validated")
        return report

    reject_existing_file(before, version)
    reject_previous_publish(client, tag, run_id)
    # Immutable bytes verified above are the very same bytes passed to multipart.
    if hashlib.sha256(archive).hexdigest() != digest:
        raise ValidationError("Installer changed after validation.")
    report["uploaded_file_id"] = client.upload_once(version, run_attempt, archive, metadata)
    report.update(real_upload_post=True, result="published")
    return report


def main():
    report = {"real_upload_post": False}
    client = None
    exit_code = 0
    try:
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
        event_name = os.environ["GITHUB_EVENT_NAME"]
        if os.environ.get("GITHUB_REPOSITORY") != REPOSITORY:
            raise ValidationError("This publisher is restricted to TomXingCan/CarGOUI.")
        if event_name == "release":
            release = event.get("release", {})
            tag = release.get("tag_name", "")
            try:
                stable_version(tag)
            except ValidationError:
                report["result"] = "ignored non-stable release"
                return 0
            if event.get("action") != "published" or release.get("draft") or release.get("prerelease"):
                report["result"] = "ignored non-final release"
                return 0
            mode = "publish"
        elif event_name == "workflow_dispatch":
            if os.environ.get("GITHUB_REF") != "refs/heads/main":
                raise ValidationError("Manual runs must use the protected main branch.")
            tag = event.get("inputs", {}).get("tag", "")
            mode = event.get("inputs", {}).get("mode", "validate")
        else:
            raise ValidationError("Unsupported workflow event.")
        validate_project_id(os.environ.get("CURSEFORGE_PROJECT_ID", ""))
        # Reject 1.0.0 publish and reruns before creating a credentialed client.
        if mode == "publish":
            ensure_upload_allowed(stable_version(tag), os.environ.get("GITHUB_RUN_ATTEMPT", "1"))
        client = Client(os.environ.get("CURSEFORGE_API_TOKEN", ""), os.environ.get("GITHUB_TOKEN", ""))
        execute(client, tag=tag, mode=mode, project_id=os.environ.get("CURSEFORGE_PROJECT_ID", ""),
                run_attempt=os.environ.get("GITHUB_RUN_ATTEMPT", "1"),
                run_id=os.environ.get("GITHUB_RUN_ID", ""), report=report)
    except ValidationError as exc:
        report.update(result="failed", error=str(exc))
        exit_code = 1
    except Exception:
        # Do not render exception text/tracebacks: third-party bodies can echo headers.
        report.update(result="failed", error="Unexpected validation failure; no automatic retry.")
        exit_code = 1
    finally:
        report["upload_post_attempts"] = client.upload_attempts if client else 0
        report["real_upload_post"] = bool(report["upload_post_attempts"])
        rendered = json.dumps(report, indent=2, sort_keys=True)
        print(rendered)
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a", encoding="utf-8") as output:
                output.write("## CurseForge release validation\n\n```json\n" + rendered + "\n```\n")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
