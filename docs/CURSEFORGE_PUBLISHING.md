# CurseForge releases

The `Publish to CurseForge` workflow consumes the existing assets of a published
GitHub Release. It never builds an installer, checks out addon source to package
it, or asks CurseForge to package source. Only publisher scripts are checked out
from protected `main`.

Configure the repository secret `CURSEFORGE_API_TOKEN` and repository variable
`CURSEFORGE_PROJECT_ID` (exactly `1712424`). The workflow has only `contents: read`
permission. Credentials stay in the runner process and authenticated requests;
no artifacts, caches, response bodies, or authentication headers are logged.

## Validate first

In Actions, open **Publish to CurseForge**, choose **Run workflow**, use branch
`main`, mode `validate` (the default), and the existing release tag. The initial
validation uses `v1.0.0`. Validation performs GET requests only and compares the
CurseForge file IDs before and after. It constructs upload metadata in memory
without sending an upload POST.

`1.0.0` was published manually. It is permanently blocked from uploading, even
when explicitly selected in publish mode. Validation exercises this guard and
can still verify the existing installer.

## Future stable releases

A published, non-prerelease GitHub Release with a canonical `vX.Y.Z` tag triggers
publishing. RC, alpha, beta, and other tag formats are ignored. The release must
already contain exactly these two complete named assets:

- `CarGOUI-X.Y.Z.zip`
- `CarGOUI-X.Y.Z.sha256`

The SHA256 file must contain one hexadecimal SHA256, optionally followed by the
exact ZIP filename in `sha256sum` format. Missing assets or a checksum mismatch
stop the run. ZIP validation requires exactly `CarGOUI` and `CarGOUI_Data` roots,
matching version and Interface metadata in both TOCs, declared runtime files,
and no development payloads, wrapped source archive, unsafe paths, or symlinks.
The downloaded bytes are kept unchanged in memory through the final upload.

The author API is `https://wow.curseforge.com`. The workflow checks authentication
with `/api/game/versions`, verifies the project through `/api/projects`, and
checks existing files through `/api/projects/1712424/files`. It resolves the
Retail type with `/api/game/version-types` and selects exactly one version whose
name matches the Interface declared in the installer (`120100` means `12.1.0`).
No game version ID is hardcoded. Unknown API schemas, incomplete file listings,
or ambiguous project/version matches fail closed and require investigation.

Upload metadata uses `releaseType: release`, the GitHub Release body as Markdown,
or a short English fallback when the body is empty. A single multipart request
to `/api/projects/1712424/upload-file` contains this metadata and the verified ZIP.
See the [official author Upload API documentation](https://support.curseforge.com/support/solutions/articles/9000197321).

## Duplicate and failure handling

Runs for the same tag share a concurrency group; active runs are never cancelled
to start another upload. Upload reruns are refused, and an earlier publish run
for the same tag or an existing matching CurseForge file blocks a new publish.
The HTTP client never retries POST, follows authenticated redirects, or treats
an uncertain network result as permission to send another upload.

After an upload timeout or unconfirmed response, inspect CurseForge and the
original run before any manual recovery. Do not rerun publish blindly. If API
contracts or recovery rules need changing, update these scripts through a PR to
protected `main`; do not change protected release tags or release installer bytes.

Offline regression tests use synthetic in-memory ZIPs and mocked transport:
`python3 -B -m unittest discover -s .github/scripts -p 'test_*.py' -v`.
