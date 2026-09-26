"""Prepare generated CarGOUI artwork for the WoW UI.

Requires Pillow. Regenerate with `python Media/Branding/generate.py`, or validate
existing files with `--check`. Source PNGs and generation prompts are retained.
Only production alpha cleanup, transparent cropping, aspect-preserving resizing,
aligned mask derivation, and format conversion happen here; this does not draw
the brand wordmark or emblem and does not edit the user's reference image.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parent
RUNTIME_SIZES = {
    "wordmark": (512, 128),
    "wordmark-mask": (512, 128),
    "emblem": (128, 128),
    "sweep": (32, 128),
}


def read_art(name, size, content_size):
    source = ROOT / "source" / (name + "-generated.png")
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    alpha = image.getchannel("A")
    # The generator left near-invisible alpha 1-3 speckles in empty margins.
    # Removing these is alpha cleanup, not a black/color-key extraction.
    image.putalpha(alpha.point(lambda value: 0 if value <= 3 else value))
    bounds = image.getchannel("A").getbbox()
    if not bounds:
        raise ValueError(f"{source.name} has no visible alpha")
    trimmed = image.crop(bounds)
    trimmed.thumbnail(content_size, Image.Resampling.LANCZOS)
    # RGBA thumbnail resampling in Pillow uses premultiplied alpha, avoiding
    # colored/dark halos from fully transparent pixels around the letters.
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    offset = ((size[0] - trimmed.width) // 2, (size[1] - trimmed.height) // 2)
    canvas.alpha_composite(trimmed, offset)
    return canvas, {
        "source": "source/" + source.name,
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_alpha_crop": list(bounds),
        "fitted_size": list(trimmed.size),
        "fitted_offset": list(offset),
    }


def save_tga(name, image):
    width, height = image.size
    # Uncompressed true-color BGRA, 8-bit alpha, top-left origin.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)
    (ROOT / (name + ".tga")).write_bytes(header + image.tobytes("raw", "BGRA"))


def prepare():
    wordmark, word_source = read_art("wordmark", (512, 128), (500, 116))
    emblem, emblem_source = read_art("emblem", (128, 128), (120, 120))
    mask = Image.new("RGBA", wordmark.size, (0, 0, 0, 0))
    for y in range(wordmark.height):
        for x in range(wordmark.width):
            alpha = wordmark.getpixel((x, y))[3]
            if alpha:
                mask.putpixel((x, y), (255, 255, 255, alpha))
    sweep = Image.new("RGBA", (32, 128), (255, 255, 255, 0))
    for x in range(32):
        # Cosine-squared lobe reaches exact alpha 0 at both strip edges.
        value = round(255 * math.sin(math.pi * x / 31) ** 2)
        for y in range(128):
            sweep.putpixel((x, y), (255, 255, 255, value))
    images = {"wordmark": wordmark, "wordmark-mask": mask, "emblem": emblem, "sweep": sweep}
    for name, image in images.items():
        save_tga(name, image)

    # A small padded shared UV rectangle keeps resampling away from the canvas
    # edge. Art and mask must use this exact same rectangle at runtime.
    left, top, right, bottom = wordmark.getchannel("A").getbbox()
    content_bounds = [max(0, left - 2), max(0, top - 2), min(512, right + 2), min(128, bottom + 2)]
    l, t, r, b = content_bounds
    aspect = (r - l) / (b - t)
    display_height = min(44, 224 / aspect)
    metadata = {
        "wordmark": word_source,
        "emblem": emblem_source,
        "wordmark_uv_pixels": content_bounds,
        "wordmark_texcoord": [l / 512, r / 512, t / 128, b / 128],
        "wordmark_display_size": [display_height * aspect, display_height],
        "wordmark_alpha_bounds": list(wordmark.getchannel("A").getbbox()),
        "emblem_alpha_bounds": list(emblem.getchannel("A").getbbox()),
        "runtime_files": {name + ".tga": {
            "size": list(image.size), "bytes": (ROOT / (name + ".tga")).stat().st_size,
            "sha256": hashlib.sha256((ROOT / (name + ".tga")).read_bytes()).hexdigest(),
        } for name, image in images.items()},
    }
    metadata["runtime_total_bytes"] = sum(item["bytes"] for item in metadata["runtime_files"].values())
    (ROOT / "source" / "production-manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: metadata[key] for key in ("wordmark_texcoord", "wordmark_display_size", "wordmark_alpha_bounds", "emblem_alpha_bounds", "runtime_total_bytes")}, indent=2))


def validate():
    manifest = json.loads((ROOT / "source" / "production-manifest.json").read_text(encoding="utf-8"))
    total = 0
    for name, expected in RUNTIME_SIZES.items():
        raw = (ROOT / (name + ".tga")).read_bytes()
        _, cmap, kind, _, _, _, _, _, width, height, depth, descriptor = struct.unpack("<BBBHHBHHHHBB", raw[:18])
        assert cmap == 0 and kind == 2, name + ": uncompressed true-color required"
        assert (width, height) == expected and all(n & (n - 1) == 0 for n in expected), name + ": dimensions"
        assert depth == 32 and descriptor == 0x28, name + ": RGBA/top-left origin"
        assert len(raw) == 18 + width * height * 4, name + ": payload length"
        assert hashlib.sha256(raw).hexdigest() == manifest["runtime_files"][name + ".tga"]["sha256"], name + ": manifest digest"
        with Image.open(ROOT / (name + ".tga")) as image:
            assert image.mode == "RGBA" and image.size == expected, name + ": decoding"
            assert image.getpixel((0, 0))[3] == 0, name + ": transparent corner"
        total += len(raw)
    with Image.open(ROOT / "wordmark.tga") as art, Image.open(ROOT / "wordmark-mask.tga") as mask:
        assert art.getchannel("A").tobytes() == mask.getchannel("A").tobytes(), "mask alignment"
        pixels = mask.tobytes()
        assert all(pixels[i:i + 3] == (bytes((255, 255, 255)) if pixels[i + 3] else bytes(3))
                   for i in range(0, len(pixels), 4)), "white glyph / transparent-black exterior mask RGB"
    assert total == manifest["runtime_total_bytes"] and total < 1024 * 1024, "runtime texture budget"
    print(f"Verified 4 uncompressed 32-bit TGA textures, aligned glyph alpha, and {total} byte runtime budget.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing assets without rewriting them.")
    if not parser.parse_args().check:
        prepare()
    validate()
