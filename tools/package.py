"""Build and test the two-addon installer from a clean Git commit.

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
    for toc, parent in (("CarGOUI.toc", ""), (prefix + "CarGOUI_Data.toc", prefix)):
        lines = files[toc].decode("utf-8-sig").splitlines()
        entries = [line.strip().replace("\\", "/") for line in lines if line.strip() and not line.startswith("#")]
        assert len(entries) == len(set(entries)), "Duplicate TOC entries"
        assert all(parent + entry in files for entry in entries), "Missing TOC source"
        if parent:
            assert "## LoadOnDemand: 1" in lines and "## Dependencies: CarGOUI" in lines
        else:
            assert not any("Classes/" in entry for entry in entries), "Core must not list class files"
    result = {}
    for path, data in files.items():
        assert "CarGOUI_Mage/" not in path, "Obsolete Mage package remains in source snapshot"
        if path.startswith("Media/Branding/source/"):
            continue
        target = "CarGOUI_Data/" + path[len(prefix):] if path.startswith(prefix) else "CarGOUI/" + path
        result[target] = data
    assert {path.split("/")[0] for path in result} == {"CarGOUI", "CarGOUI_Data"}
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
    target = args.output / ("CarGOUI-" + version + "-Options-Combat-Lock.zip")
    installed = install_files(files)
    digest = write_archive(installed, target)
    extraction = args.output / ("package-check-" + digest[:12])
    assert not extraction.exists(), "Verification directory already exists; choose a new output directory"
    extraction.mkdir()
    with zipfile.ZipFile(target) as archive:
        archive.extractall(extraction)
    lines = ["Version: " + version, "Commit: " + commit, "Tree: " + tree,
             "Archive: " + target.name, "SHA256: " + digest,
             "Verification: extracted final installer; no real WoW client acceptance."]
    failed = False
    for test in ("run_tests.py", "check_mobility_static.py", "check_styles_theme_static.py", "check_proc_static.py"):
        result = subprocess.run([sys.executable, str(extraction / "CarGOUI/tests" / test)],
                                cwd=extraction / "CarGOUI", env=os.environ,
                                capture_output=True, text=True, encoding="utf-8")
        lines += ["\n" + test + ": exit " + str(result.returncode), result.stdout, result.stderr]
        failed = failed or result.returncode != 0
    target.with_suffix(".tests.txt").write_text("\n".join(lines), encoding="utf-8")
    target.with_suffix(".sha256").write_text(digest + "  " + target.name + "\n", encoding="ascii")
    print(json.dumps({"archive": str(target), "sha256": digest, "files": len(installed), "tests_passed": not failed}))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
