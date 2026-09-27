#!/usr/bin/env python3
"""Run the complete offline suite with actual Lua 5.1 via lupa.lua51.

Python JSON/Base64 mocks exercise untrusted strings across the Lua boundary.
They do not prove native WoW codec behavior. No dependency is auto-installed.
"""

from __future__ import annotations

import argparse
import importlib
import sys
from pathlib import Path

from encoding_fixture import install as install_encoding_fixture


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", help="Legacy standalone mode; complete RC tests require lupa.lua51")
    parser.add_argument("--addon-root", type=Path,
                        help="CarGOUI runtime directory to inspect (including an extracted installer)")
    args = parser.parse_args()
    script = Path(__file__).resolve().with_name("smoke.lua")
    addon_root = (args.addon_root or script.parent.parent).resolve()
    if not (addon_root / "CarGOUI.toc").is_file():
        parser.error("--addon-root must contain CarGOUI.toc")

    if args.lua:
        parser.error("The complete RC suite needs Python's JSON/Base64 bridge. Omit --lua and use an environment containing lupa.lua51; no tests are silently skipped.")

    try:
        lua51 = importlib.import_module("lupa.lua51")
    except ImportError:
        print(
            "The complete suite requires lupa.lua51 for actual Lua 5.1 plus Python JSON/Base64 fixtures. "
            "Use an existing Python environment containing lupa.lua51. Nothing was installed or skipped.",
            file=sys.stderr,
        )
        return 2

    runtime = lua51.LuaRuntime(unpack_returned_tuples=True)
    assert runtime.eval("_VERSION") == "Lua 5.1", "A compatibility shim is not an accepted runtime"
    install_encoding_fixture(runtime)
    print(f"Runtime: actual Lua 5.1 via lupa.lua51; Python JSON/Base64 offline fixture; addon root: {addon_root}", flush=True)
    runtime.globals().arg = runtime.table_from({1: str(addon_root), 2: str(script.parent)})
    try:
        runtime.execute(script.read_text(encoding="utf-8"), name=str(script))
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
