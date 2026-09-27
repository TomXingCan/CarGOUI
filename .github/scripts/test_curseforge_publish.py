"""Offline safety tests for publishing existing CarGOUI release assets."""

import hashlib
import contextlib
import email.policy
from email.parser import BytesParser
import io
import json
import os
import struct
import unittest
from unittest.mock import Mock, patch
import urllib.error
import urllib.request
import warnings
import zipfile

import curseforge_publish as publisher
from curseforge_validation import (
    ValidationError,
    build_metadata,
    ensure_upload_allowed,
    inspect_zip,
    select_assets,
    stable_version,
    verify_checksum,
)


def release_fixture(version="1.0.1"):
    """A published release containing the two expected uploaded assets."""
    return {
        "tag_name": f"v{version}",
        "draft": False,
        "prerelease": False,
        "published_at": "2026-09-28T00:00:00Z",
        "body": "Release notes with **Markdown**.",
        "assets": [
            {
                "id": 1,
                "name": f"CarGOUI-{version}.zip",
                "state": "uploaded",
                "size": 100,
                "browser_download_url": f"https://github.com/example/CarGOUI/releases/download/v{version}/CarGOUI-{version}.zip",
            },
            {
                "id": 2,
                "name": f"CarGOUI-{version}.sha256",
                "state": "uploaded",
                "size": 90,
                "browser_download_url": f"https://github.com/example/CarGOUI/releases/download/v{version}/CarGOUI-{version}.sha256",
            },
        ],
    }


def zip_fixture(version="1.0.1", changes=None, remove=()):
    """Build a tiny real installable archive entirely in memory."""
    files = {
        "CarGOUI/CarGOUI.toc": (
            f"## Interface: 120100\n## Title: CarGOUI\n## Version: {version}\nCore\\Addon.lua\n"
        ),
        "CarGOUI/Core/Addon.lua": "-- addon\n",
        "CarGOUI_Data/CarGOUI_Data.toc": (
            f"## Interface: 120100\n## Title: CarGOUI - Data\n## Version: {version}\n"
            "## Dependencies: CarGOUI\n## LoadOnDemand: 1\nBootstrap.lua\n"
        ),
        "CarGOUI_Data/Bootstrap.lua": "-- data addon\n",
    }
    files.update(changes or {})
    for name in remove:
        files.pop(name)
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)
    return output.getvalue()


class StableVersionTests(unittest.TestCase):
    def test_stable_tag_produces_exact_asset_version(self):
        self.assertEqual(stable_version("v1.0.1"), "1.0.1")
        self.assertEqual(stable_version("v2.10.30"), "2.10.30")

    def test_nonstable_and_malformed_tags_are_rejected(self):
        for tag in (
            "v1.0.1-rc.1", "v1.0.1-beta", "v1.0.1-alpha.2", "1.0.1",
            "v1.0", "release-v1.0.1", "v1.0.1\n", "v01.0.1", "v1.0.1+build",
        ):
            with self.subTest(tag=tag), self.assertRaises(ValidationError):
                stable_version(tag)

    def test_manually_published_100_always_blocks_upload(self):
        with self.assertRaises(ValidationError) as failure:
            ensure_upload_allowed("1.0.0")
        self.assertEqual(
            str(failure.exception),
            "CarGOUI 1.0.0 was already published manually; duplicate upload blocked.",
        )

    def test_first_attempt_can_publish_later_stable_version(self):
        self.assertIsNone(ensure_upload_allowed("1.0.1", "1"))

    def test_workflow_rerun_cannot_repeat_upload(self):
        for attempt in ("2", "3", "0", "", "abc"):
            with self.subTest(attempt=attempt), self.assertRaises(ValidationError):
                ensure_upload_allowed("1.0.1", attempt)


class ReleaseAssetTests(unittest.TestCase):
    def test_selects_existing_named_release_assets(self):
        release = release_fixture()
        zip_asset, checksum_asset = select_assets(release, "1.0.1")
        self.assertIs(zip_asset, release["assets"][0])
        self.assertIs(checksum_asset, release["assets"][1])

    def test_missing_zip_or_checksum_fails(self):
        for removed in (0, 1):
            release = release_fixture()
            release["assets"].pop(removed)
            with self.subTest(removed=removed), self.assertRaises(ValidationError):
                select_assets(release, "1.0.1")

    def test_draft_prerelease_or_mismatched_tag_fails(self):
        for change in ({"draft": True}, {"prerelease": True}, {"tag_name": "v2.0.0"}):
            release = release_fixture()
            release.update(change)
            with self.subTest(change=change), self.assertRaises(ValidationError):
                select_assets(release, "1.0.1")

    def test_duplicate_asset_name_fails(self):
        release = release_fixture()
        release["assets"].append(dict(release["assets"][0], id=3))
        with self.assertRaises(ValidationError):
            select_assets(release, "1.0.1")

    def test_unfinished_or_empty_assets_fail(self):
        for change in ({"state": "new"}, {"size": 0}):
            release = release_fixture()
            release["assets"][0].update(change)
            with self.subTest(change=change), self.assertRaises(ValidationError):
                select_assets(release, "1.0.1")


class ChecksumTests(unittest.TestCase):
    def setUp(self):
        self.zip_bytes = zip_fixture()
        self.filename = "CarGOUI-1.0.1.zip"
        self.digest = hashlib.sha256(self.zip_bytes).hexdigest()

    def test_verifies_exact_zip_bytes_in_supported_formats(self):
        for checksum in (
            self.digest,
            f"{self.digest}  {self.filename}\n",
            f"{self.digest.upper()} *{self.filename}\n",
        ):
            with self.subTest(checksum=checksum):
                self.assertEqual(
                    verify_checksum(self.zip_bytes, checksum.encode(), self.filename), self.digest
                )

    def test_modified_zip_fails(self):
        with self.assertRaises(ValidationError):
            verify_checksum(self.zip_bytes + b"tampered", self.digest.encode(), self.filename)

    def test_wrong_hash_or_filename_fails(self):
        for checksum in ("0" * 64, f"{self.digest}  another.zip", "not a checksum", ""):
            with self.subTest(checksum=checksum), self.assertRaises(ValidationError):
                verify_checksum(self.zip_bytes, checksum.encode(), self.filename)

    def test_ambiguous_multiline_checksum_fails(self):
        checksum = f"{self.digest}  {self.filename}\n{self.digest}  another.zip\n"
        with self.assertRaises(ValidationError):
            verify_checksum(self.zip_bytes, checksum.encode(), self.filename)


class ArchiveTests(unittest.TestCase):
    def test_two_addon_roots_and_tocs_define_target_retail_version(self):
        result = inspect_zip(zip_fixture(), "1.0.1")
        self.assertEqual(result["interface"], 120100)
        self.assertEqual(result["game_version"], "12.1.0")
        self.assertEqual(result["file_count"], 4)

    def test_forbidden_development_paths_fail(self):
        for path in (
            ".git/config", "CarGOUI/.git/config", "CarGOUI/tests/example.txt",
            "CarGOUI/tmp/output.txt", "CarGOUI/dist/output.txt", "CarGOUI/build/output.txt",
            "CarGOUI-1.0.1/README.md", "README.md",
        ):
            with self.subTest(path=path), self.assertRaises(ValidationError):
                inspect_zip(zip_fixture(changes={path: "unwanted"}), "1.0.1")

    def test_path_traversal_and_absolute_paths_fail(self):
        for path in ("CarGOUI/../outside.txt", "/CarGOUI/file.txt", "CarGOUI/../../outside.txt"):
            with self.subTest(path=path), self.assertRaises(ValidationError):
                inspect_zip(zip_fixture(changes={path: "unwanted"}), "1.0.1")

    def test_missing_root_toc_fails(self):
        with self.assertRaises(ValidationError):
            inspect_zip(zip_fixture(remove=("CarGOUI_Data/CarGOUI_Data.toc",)), "1.0.1")

    def test_toc_version_must_match_release(self):
        with self.assertRaises(ValidationError):
            inspect_zip(zip_fixture(version="1.0.0"), "1.0.1")

    def test_addon_interfaces_must_match(self):
        toc = "## Interface: 120000\n## Version: 1.0.1\nBootstrap.lua\n"
        with self.assertRaises(ValidationError):
            inspect_zip(zip_fixture(changes={"CarGOUI_Data/CarGOUI_Data.toc": toc}), "1.0.1")

    def test_toc_references_must_be_present(self):
        with self.assertRaises(ValidationError):
            inspect_zip(zip_fixture(remove=("CarGOUI/Core/Addon.lua",)), "1.0.1")

    def test_unlisted_lua_files_fail(self):
        with self.assertRaises(ValidationError):
            inspect_zip(zip_fixture(changes={"CarGOUI/Debug.lua": "-- forgotten debug code"}), "1.0.1")

    def test_invalid_zip_fails(self):
        with self.assertRaises(ValidationError):
            inspect_zip(b"this is not a ZIP", "1.0.1")

    def test_zip_symlink_fails(self):
        output = io.BytesIO(zip_fixture())
        with zipfile.ZipFile(output, "a") as archive:
            link = zipfile.ZipInfo("CarGOUI/link")
            link.create_system = 3
            link.external_attr = (0o120777 << 16)
            archive.writestr(link, "../../outside")
        with self.assertRaises(ValidationError):
            inspect_zip(output.getvalue(), "1.0.1")

    def test_duplicate_zip_member_fails(self):
        output = io.BytesIO(zip_fixture())
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(output, "a") as archive:
                archive.writestr("CarGOUI/Core/Addon.lua", "-- duplicate\n")
        with self.assertRaises(ValidationError):
            inspect_zip(output.getvalue(), "1.0.1")

    def test_case_colliding_directories_fail_even_when_lua_is_declared(self):
        toc = "## Interface: 120100\n## Version: 1.0.1\nCore/Addon.lua\ncore/Other.lua\n"
        archive = zip_fixture(changes={
            "CarGOUI/CarGOUI.toc": toc,
            "CarGOUI/core/Other.lua": "-- case collision\n",
        })
        with self.assertRaises(ValidationError):
            inspect_zip(archive, "1.0.1")

    def test_corrupt_member_crc_fails(self):
        source = io.BytesIO(zip_fixture())
        output = io.BytesIO()
        with zipfile.ZipFile(source) as original, zipfile.ZipFile(output, "w", zipfile.ZIP_STORED) as archive:
            for member in original.infolist():
                archive.writestr(member.filename, original.read(member))
        damaged = output.getvalue().replace(b"-- addon\n", b"-- add0n\n", 1)
        with self.assertRaises(ValidationError):
            inspect_zip(damaged, "1.0.1")

    def test_encrypted_member_flag_fails(self):
        archive = bytearray(zip_fixture())
        local = archive.index(b"PK\x03\x04")
        central = archive.index(b"PK\x01\x02")
        for offset in (local + 6, central + 8):
            flags = struct.unpack_from("<H", archive, offset)[0]
            struct.pack_into("<H", archive, offset, flags | 1)
        with self.assertRaises(ValidationError):
            inspect_zip(bytes(archive), "1.0.1")


class MetadataTests(unittest.TestCase):
    def test_metadata_is_valid_json_and_preserves_release_body(self):
        body = 'Release notes: **stable**.\nUnicode: 修复\nQuoted: "yes"'
        metadata = build_metadata("1.0.1", body, 123456)
        decoded = json.loads(json.dumps(metadata))
        self.assertEqual(decoded["releaseType"], "release")
        self.assertEqual(decoded["changelogType"], "markdown")
        self.assertEqual(decoded["changelog"], body)
        self.assertEqual(decoded["gameVersions"], [123456])
        self.assertIn("1.0.1", decoded["displayName"])

    def test_empty_body_has_nonempty_english_fallback(self):
        for body in (None, "", "  \n"):
            with self.subTest(body=body):
                metadata = build_metadata("1.0.1", body, 123456)
                self.assertTrue(metadata["changelog"].strip())
                self.assertTrue(metadata["changelog"].isascii())
                self.assertIn("1.0.1", metadata["changelog"])

    def test_invalid_game_version_id_fails(self):
        for game_version_id in (None, 0, -1, True, "123456"):
            with self.subTest(game_version_id=game_version_id), self.assertRaises(ValidationError):
                build_metadata("1.0.1", "Changes", game_version_id)


def manual_file_fixture(**changes):
    record = {
        "id": 8990958,
        "projectId": 1712424,
        "fileName": "CarGOUI-1.0.0.zip",
        "displayName": "CarGOUI 1.0.0",
        "fileLength": 388040,
    }
    record.update(changes)
    return record


def api_client_fixture(version="1.0.1"):
    """A mocked API client with real release archive and checksum inputs."""
    archive = zip_fixture(version)
    checksum = hashlib.sha256(archive).hexdigest().encode()
    release = release_fixture(version)
    client = Mock(spec=publisher.Client)
    client.upload_attempts = 0
    responses = {
        f"{publisher.GH_ORIGIN}/repos/{publisher.REPOSITORY}/releases/tags/v{version}": release,
        f"{publisher.CF_ORIGIN}/api/game/versions": [
            {"id": 123456, "name": "12.1.0", "gameVersionTypeID": 517},
        ],
        f"{publisher.CF_ORIGIN}/api/game/version-types": [
            {"id": 517, "name": "WoW Retail", "slug": "wow-retail"},
        ],
    }
    client.get_json.side_effect = lambda url: responses[url]
    client.asset.side_effect = lambda asset, tag: archive if asset["name"].endswith(".zip") else checksum
    client.project_files.return_value = [manual_file_fixture()]
    client.manual_baseline_archive.return_value = zip_fixture("1.0.0")
    return client, responses, archive


class ExecutionSafetyTests(unittest.TestCase):
    def setUp(self):
        # The published baseline is tested separately; these executions use tiny
        # synthetic fixtures and never download a file or weaken production rules.
        baseline = patch.object(publisher, "verify_manual_baseline", return_value=None)
        self.baseline_validator = baseline.start()
        self.addCleanup(baseline.stop)

    def test_validate_100_performs_no_upload_and_confirms_unchanged_files(self):
        client, _, _ = api_client_fixture("1.0.0")
        result = publisher.execute(client, tag="v1.0.0", mode="validate", project_id="1712424")
        client.upload_once.assert_not_called()
        self.assertEqual(result["curseforge_files_before"], [8990958])
        self.assertEqual(result["curseforge_files_after"], [8990958])
        self.assertFalse(result["real_upload_post"])
        self.assertFalse(result["new_curseforge_files"])
        self.assertEqual(result["duplicate_guard_1_0_0"], "passed")
        self.assertEqual(result["sha256_check"], "passed")
        self.assertEqual(result["zip_structure"], "passed")
        self.assertEqual(result["token_authentication"], "passed")
        self.assertEqual(result["game_version_id"], 123456)
        self.baseline_validator.assert_called_once_with(client.manual_baseline_archive.return_value)

    def test_wrong_project_id_fails_before_network_or_upload(self):
        client, _, _ = api_client_fixture()
        with self.assertRaises(ValidationError):
            publisher.execute(client, tag="v1.0.1", mode="validate", project_id="999")
        client.get_json.assert_not_called()
        client.asset.assert_not_called()
        client.upload_once.assert_not_called()
        self.baseline_validator.assert_not_called()

    def test_100_publish_fails_before_network_or_upload(self):
        client, _, _ = api_client_fixture("1.0.0")
        with self.assertRaisesRegex(ValidationError, "already published manually"):
            publisher.execute(client, tag="v1.0.0", mode="publish", project_id="1712424")
        client.get_json.assert_not_called()
        client.upload_once.assert_not_called()

    def test_validate_detects_external_file_list_change(self):
        client, _, _ = api_client_fixture()
        client.project_files.side_effect = [
            [manual_file_fixture()],
            [manual_file_fixture(), manual_file_fixture(id=9002, fileName="external.zip")],
        ]
        with self.assertRaisesRegex(ValidationError, "file list changed"):
            publisher.execute(client, tag="v1.0.1", mode="validate", project_id="1712424")
        client.upload_once.assert_not_called()

    def test_publish_passes_verified_original_archive_once(self):
        client, responses, archive = api_client_fixture()
        responses[
            f"{publisher.GH_ORIGIN}/repos/{publisher.REPOSITORY}/actions/workflows/publish-curseforge.yml/runs?per_page=100&page=1"
        ] = {"workflow_runs": []}
        client.upload_once.return_value = 9002
        result = publisher.execute(client, tag="v1.0.1", mode="publish", project_id="1712424")
        client.upload_once.assert_called_once()
        self.assertIs(client.upload_once.call_args.args[2], archive)
        self.assertEqual(result["uploaded_file_id"], 9002)

    def test_prior_publish_run_blocks_new_upload_attempt(self):
        client, responses, _ = api_client_fixture()
        responses[
            f"{publisher.GH_ORIGIN}/repos/{publisher.REPOSITORY}/actions/workflows/publish-curseforge.yml/runs?per_page=100&page=1"
        ] = {"workflow_runs": [{"id": 123, "display_title": "CurseForge v1.0.1 (publish)"}]}
        with self.assertRaisesRegex(ValidationError, "publish run already exists"):
            publisher.execute(client, tag="v1.0.1", mode="publish", project_id="1712424", run_id="124")
        client.upload_once.assert_not_called()


class ApiIdentityTests(unittest.TestCase):
    def test_project_must_match_immutable_manual_release_identity(self):
        valid = manual_file_fixture()
        self.assertEqual(publisher.confirm_project([valid]), valid)
        for payload in (
            [], [valid, valid], [dict(valid, projectId=999)], [dict(valid, id=999)],
            [dict(valid, fileName="Other.zip")], [dict(valid, displayName="Other")],
            [dict(valid, fileLength=123)], [valid, dict(valid, id=9002, projectId=999)],
        ):
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                publisher.confirm_project(payload)

    def test_version_is_resolved_from_unique_live_retail_type(self):
        types = [{"id": 517, "name": "WoW Retail"}, {"id": 999, "name": "WoW Classic"}]
        versions = [
            {"id": 123456, "name": "12.1.0", "gameVersionTypeID": 517},
            {"id": 987654, "name": "12.1.0", "gameVersionTypeID": 999},
        ]
        self.assertEqual(publisher.resolve_game_version(versions, types, "12.1.0"), (123456, 517))

    def test_unknown_or_ambiguous_retail_mapping_fails_closed(self):
        types = [{"id": 517, "name": "WoW Retail"}]
        versions = [{"id": 123456, "name": "12.1.0", "gameVersionTypeID": 517}]
        for game_versions, version_types in (
            ([], types), (versions + versions, types), (versions, []),
            (versions, types + types), ([dict(versions[0], gameVersionTypeID=999)], types),
        ):
            with self.subTest(versions=game_versions, types=version_types), self.assertRaises(ValidationError):
                publisher.resolve_game_version(game_versions, version_types, "12.1.0")

    def test_manual_baseline_rejects_any_unapproved_archive(self):
        with self.assertRaisesRegex(ValidationError, "approved baseline"):
            publisher.verify_manual_baseline(zip_fixture("1.0.0"))

    def test_matching_baseline_checksum_still_requires_valid_100_package(self):
        valid_archive = zip_fixture("1.0.0")
        with patch.object(publisher, "MANUAL_BASELINE_SHA256", hashlib.sha256(valid_archive).hexdigest()):
            self.assertIsNone(publisher.verify_manual_baseline(valid_archive))
        invalid_archive = zip_fixture("1.0.1")
        with patch.object(publisher, "MANUAL_BASELINE_SHA256", hashlib.sha256(invalid_archive).hexdigest()):
            with self.assertRaises(ValidationError):
                publisher.verify_manual_baseline(invalid_archive)


class PublicFileListingTests(unittest.TestCase):
    def make_client(self, pages):
        client = publisher.Client("unit-test-curseforge-secret-marker")
        client.get_json = Mock(side_effect=pages)
        return client

    def page(self, records, total, index=0):
        return {"data": records, "pagination": {"index": index, "pageSize": 50, "totalCount": total}}

    def test_all_pages_are_combined_before_duplicate_checks(self):
        first = [manual_file_fixture(id=8990900 + index) for index in range(50)]
        second = [manual_file_fixture()]
        client = self.make_client([self.page(first, 51), self.page(second, 51, 1)])
        self.assertEqual(client.project_files(), first + second)
        self.assertEqual(client.get_json.call_count, 2)
        urls = [call.args[0] for call in client.get_json.call_args_list]
        self.assertEqual(urls, [
            f"{publisher.CF_PUBLIC_ORIGIN}/api/v1/mods/1712424/files?pageIndex=0&pageSize=50",
            f"{publisher.CF_PUBLIC_ORIGIN}/api/v1/mods/1712424/files?pageIndex=1&pageSize=50",
        ])

    def test_single_and_empty_complete_pages_are_supported(self):
        for records in ([], [manual_file_fixture()]):
            with self.subTest(count=len(records)):
                client = self.make_client([self.page(records, len(records))])
                self.assertEqual(client.project_files(), records)
                client.get_json.assert_called_once()

    def test_incomplete_or_invalid_pagination_fails(self):
        for payload in (
            self.page([], 1), self.page([manual_file_fixture()], 2),
            self.page([manual_file_fixture()], 1, 1),
            {"data": [manual_file_fixture()]},
            {"data": [manual_file_fixture()], "pagination": None},
            {"data": [manual_file_fixture()], "pagination": []},
            {"data": [manual_file_fixture()], "pagination": {"index": 0, "pageSize": 20, "totalCount": 1}},
        ):
            with self.subTest(payload=payload), self.assertRaises(ValidationError):
                self.make_client([payload]).project_files()

    def test_duplicate_or_cross_project_records_fail(self):
        for records in (
            [manual_file_fixture(), manual_file_fixture()],
            [manual_file_fixture(projectId=999)],
        ):
            with self.subTest(records=records), self.assertRaises(ValidationError):
                self.make_client([self.page(records, len(records))]).project_files()

    def test_total_count_changes_between_pages_fail(self):
        first = [manual_file_fixture(id=8990900 + index) for index in range(50)]
        client = self.make_client([self.page(first, 51), self.page([manual_file_fixture()], 52, 1)])
        with self.assertRaises(ValidationError):
            client.project_files()


class HttpSafetyTests(unittest.TestCase):
    # Deliberately fake markers; no real credential is read by these tests.
    FAKE_CF_TOKEN = "unit-test-curseforge-secret-marker"
    FAKE_GH_TOKEN = "unit-test-github-secret-marker"

    def make_client(self):
        client = publisher.Client(self.FAKE_CF_TOKEN, self.FAKE_GH_TOKEN)
        client._opener = Mock()
        client._asset_opener = Mock()
        client._baseline_opener = Mock()
        response = Mock()
        response.read.return_value = b'{"id": 9002}'
        client._opener.open.return_value.__enter__ = Mock(return_value=response)
        client._opener.open.return_value.__exit__ = Mock(return_value=False)
        client._baseline_opener.open.return_value.__enter__ = Mock(return_value=response)
        client._baseline_opener.open.return_value.__exit__ = Mock(return_value=False)
        return client

    def test_missing_token_is_rejected(self):
        for token in ("", "  "):
            with self.subTest(token=token), self.assertRaises(ValidationError):
                publisher.Client(token)

    def test_upload_timeout_http_error_and_invalid_response_never_retry(self):
        for failure in (
            TimeoutError(self.FAKE_CF_TOKEN),
            urllib.error.URLError(self.FAKE_CF_TOKEN),
            urllib.error.HTTPError("https://wow.curseforge.com", 302, self.FAKE_CF_TOKEN, {}, None),
            urllib.error.HTTPError("https://wow.curseforge.com", 503, self.FAKE_CF_TOKEN, {}, None),
            None,
        ):
            with self.subTest(failure_type=type(failure).__name__):
                client = self.make_client()
                if failure is None:
                    client._opener.open.return_value.__enter__.return_value.read.return_value = b"invalid JSON"
                else:
                    client._opener.open.side_effect = failure
                with self.assertRaises(ValidationError) as result:
                    client.upload_once("1.0.1", "1", zip_fixture(), build_metadata("1.0.1", "Changes", 123456))
                self.assertNotIn(self.FAKE_CF_TOKEN, str(result.exception))
                with self.assertRaisesRegex(ValidationError, "retry blocked"):
                    client.upload_once("1.0.1", "1", zip_fixture(), {})
                self.assertEqual(client.upload_attempts, 1)
                client._opener.open.assert_called_once()
                self.assertEqual(client._opener.open.call_args.args[0].get_method(), "POST")

    def test_upload_multipart_contains_exact_original_zip_and_valid_metadata(self):
        client = self.make_client()
        archive = zip_fixture()
        metadata = build_metadata("1.0.1", "Release body", 123456)
        self.assertEqual(client.upload_once("1.0.1", "1", archive, metadata), 9002)
        request = client._opener.open.call_args.args[0]
        content_type = request.get_header("Content-type")
        message = BytesParser(policy=email.policy.default).parsebytes(
            f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n".encode() + request.data
        )
        fields = {part.get_param("name", header="content-disposition"): part for part in message.iter_parts()}
        self.assertEqual(fields["file"].get_filename(), "CarGOUI-1.0.1.zip")
        self.assertEqual(fields["file"].get_payload(decode=True), archive)
        self.assertEqual(json.loads(fields["metadata"].get_payload(decode=True)), metadata)
        client._opener.open.assert_called_once()

    def test_authenticated_redirects_are_not_followed(self):
        request = urllib.request.Request("https://wow.curseforge.com/api/game/versions")
        for status in (301, 302, 303, 307, 308):
            with self.subTest(status=status):
                self.assertIsNone(publisher.NoRedirect().redirect_request(
                    request, None, status, "redirect", {}, "https://example.invalid/collect"
                ))

    def test_credentials_are_scoped_to_their_own_api_origin(self):
        client = self.make_client()
        client._request(f"{publisher.CF_ORIGIN}/api/game/versions")
        cf_headers = dict((key.lower(), value) for key, value in client._opener.open.call_args.args[0].header_items())
        self.assertEqual(cf_headers["x-api-token"], self.FAKE_CF_TOKEN)
        self.assertNotIn("authorization", cf_headers)
        client._request(f"{publisher.GH_ORIGIN}/repos/{publisher.REPOSITORY}")
        gh_headers = dict((key.lower(), value) for key, value in client._opener.open.call_args.args[0].header_items())
        self.assertEqual(gh_headers["authorization"], "Bearer " + self.FAKE_GH_TOKEN)
        self.assertNotIn("x-api-token", gh_headers)

    def test_public_project_listing_never_receives_credentials(self):
        client = self.make_client()
        url = f"{publisher.CF_PUBLIC_ORIGIN}/api/v1/mods/1712424/files?pageIndex=0&pageSize=50"
        client._request(url)
        request = client._opener.open.call_args.args[0]
        headers = dict((key.lower(), value) for key, value in request.header_items())
        self.assertNotIn("x-api-token", headers)
        self.assertNotIn("authorization", headers)
        self.assertEqual(request.get_method(), "GET")
        with self.assertRaises(ValidationError):
            client._request(url, data=b"forbidden-public-post")

    def test_manual_baseline_download_is_read_only_without_credentials(self):
        client = self.make_client()
        client.manual_baseline_archive()
        request = client._baseline_opener.open.call_args.args[0]
        headers = dict((key.lower(), value) for key, value in request.header_items())
        self.assertNotIn("x-api-token", headers)
        self.assertNotIn("authorization", headers)
        self.assertEqual(request.get_method(), "GET")
        self.assertEqual(
            request.full_url,
            f"{publisher.CF_PUBLIC_ORIGIN}/api/v1/mods/1712424/files/8990958/download",
        )
        client._opener.open.assert_not_called()
        with self.assertRaises(ValidationError):
            client._request(request.full_url, baseline=True, data=b"forbidden-baseline-post")
        with self.assertRaises(ValidationError):
            client._request(request.full_url.replace("8990958", "9999999"), baseline=True)

    def test_manual_baseline_redirect_requires_official_https_host(self):
        request = urllib.request.Request(
            f"{publisher.CF_PUBLIC_ORIGIN}/api/v1/mods/1712424/files/8990958/download"
        )
        for allowed in (
            "https://edge.forgecdn.net/files/8990/958/CarGOUI-1.0.0.zip",
            "https://mediafilez.forgecdn.net/files/8990/958/CarGOUI-1.0.0.zip",
        ):
            redirected = publisher.BaselineRedirect().redirect_request(request, None, 302, "redirect", {}, allowed)
            self.assertEqual(redirected.full_url, allowed)
        for target in (
            "https://example.invalid/CarGOUI-1.0.0.zip",
            "http://mediafilez.forgecdn.net/CarGOUI-1.0.0.zip",
            "https://user:password@mediafilez.forgecdn.net/CarGOUI-1.0.0.zip",
        ):
            with self.subTest(target=target), self.assertRaises(ValidationError):
                publisher.BaselineRedirect().redirect_request(request, None, 302, "redirect", {}, target)

    def test_main_does_not_log_tokens_from_network_errors(self):
        client = self.make_client()
        client._opener.open.side_effect = urllib.error.URLError(self.FAKE_CF_TOKEN + self.FAKE_GH_TOKEN)
        environment = {
            "GITHUB_EVENT_PATH": "unused-test-event.json",
            "GITHUB_EVENT_NAME": "workflow_dispatch",
            "GITHUB_REPOSITORY": publisher.REPOSITORY,
            "GITHUB_REF": "refs/heads/main",
            "CURSEFORGE_PROJECT_ID": "1712424",
            "CURSEFORGE_API_TOKEN": self.FAKE_CF_TOKEN,
            "GITHUB_TOKEN": self.FAKE_GH_TOKEN,
        }
        event = json.dumps({"inputs": {"tag": "v1.0.0", "mode": "validate"}})
        output = io.StringIO()
        with patch.dict(os.environ, environment, clear=True), \
                patch.object(publisher.Path, "read_text", return_value=event), \
                patch.object(publisher, "Client", return_value=client), \
                contextlib.redirect_stdout(output):
            self.assertEqual(publisher.main(), 1)
        self.assertNotIn(self.FAKE_CF_TOKEN, output.getvalue())
        self.assertNotIn(self.FAKE_GH_TOKEN, output.getvalue())
        self.assertEqual(json.loads(output.getvalue())["upload_post_attempts"], 0)


if __name__ == "__main__":
    unittest.main()
