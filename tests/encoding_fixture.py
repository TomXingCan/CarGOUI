"""Offline JSON/Base64 behavior, not an implementation of WoW's native APIs.

Python's real parsers allow malformed-string tests; no opaque reversible lookup
map is used. Lua tables are converted across the lupa.lua51 boundary. Native
empty-table serialization is unspecified, so both {} and [] are modeled.
Actual C_EncodingUtil round trips still require client acceptance.
"""
from __future__ import annotations

import base64
import json


def install(runtime):
    lua_type = runtime.eval("type")

    def to_python(value, empty_arrays=False, depth=0):
        if depth > 128:
            raise ValueError("fixture serialization nesting limit")
        kind = lua_type(value)
        if kind != "table":
            if kind not in {"nil", "boolean", "string", "number"}:
                raise TypeError("JSON does not encode functions or runtime objects")
            return value
        keys = list(value.keys())
        if not keys:
            return [] if empty_arrays else {}
        if all(isinstance(key, (int, float)) and not isinstance(key, bool)
               and key == int(key) for key in keys) and set(keys) == set(range(1, len(keys) + 1)):
            return [to_python(value[index], empty_arrays, depth + 1) for index in range(1, len(keys) + 1)]
        return {str(key): to_python(value[key], empty_arrays, depth + 1) for key in keys}

    def to_lua(value):
        if isinstance(value, dict):
            return runtime.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return runtime.table_from([to_lua(item) for item in value])
        return value

    def serialize(value, empty_arrays=False):
        return json.dumps(to_python(value, empty_arrays), ensure_ascii=False,
                          allow_nan=False, separators=(",", ":"), sort_keys=True)

    def deserialize(value):
        # Python exposes large exponents as infinity; the production validator
        # must still reject them. Null maps to Lua nil; raw scanner tests must
        # reject null before a decoder could erase an unknown object's field.
        return to_lua(json.loads(value))

    def encode(value, variant=0):
        if variant not in (None, 0, 1):
            raise ValueError("unknown Base64 variant")
        operation = base64.urlsafe_b64encode if variant == 1 else base64.b64encode
        return operation(value.encode("utf-8")).decode("ascii")

    def decode(value, variant=0):
        if variant not in (None, 0, 1):
            raise ValueError("unknown Base64 variant")
        return base64.b64decode(value, altchars=b"-_" if variant == 1 else None,
                                validate=True).decode("utf-8")

    runtime.globals()._CAR_GO_UI_TEST_CODEC = runtime.table_from({
        "serialize": serialize, "deserialize": deserialize,
        "encode": encode, "decode": decode,
    })
