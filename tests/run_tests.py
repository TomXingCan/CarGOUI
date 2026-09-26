#!/usr/bin/env python3
"""Run the offline smoke suite with Lua 5.1, LuaJIT, or lupa.lua51.

This runner has no required Python dependencies. It never installs software.
Use --lua PATH to select a Lua 5.1-compatible interpreter explicitly.
"""

from __future__ import annotations

import argparse
import importlib
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", help="Path to a Lua 5.1 or LuaJIT executable")
    args = parser.parse_args()
    script = Path(__file__).resolve().with_name("smoke.lua")
    addon_root = script.parent.parent

    candidates = [args.lua] if args.lua else [
        shutil.which(name) for name in ("lua5.1", "lua51", "luajit", "lua")
    ]
    for executable in dict.fromkeys(path for path in candidates if path):
        try:
            version = subprocess.run(
                [executable, "-e", "io.write(_VERSION)"],
                capture_output=True, text=True, check=False,
            )
        except OSError as error:
            if args.lua:
                print(f"Cannot execute {executable}: {error}", file=sys.stderr)
                return 2
            continue
        if version.returncode != 0 or version.stdout.strip() != "Lua 5.1":
            if args.lua:
                print("The selected interpreter must support Lua 5.1.", file=sys.stderr)
                return 2
            continue
        return subprocess.run(
            [executable, str(script), str(addon_root)], check=False,
        ).returncode

    try:
        lua51 = importlib.import_module("lupa.lua51")
    except ImportError:
        print(
            "No Lua 5.1 runtime found. Run this with --lua PATH_TO_LUA51, "
            "put Lua 5.1/LuaJIT on PATH, or use a Python environment containing lupa.lua51.",
            file=sys.stderr,
        )
        return 2

    runtime = lua51.LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().arg = runtime.table_from({1: str(addon_root)})
    try:
        runtime.execute(script.read_text(encoding="utf-8"), name=str(script))
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
