"""Regenerate original CarGOUI vector sources and WoW-safe textures.

Requires Pillow. Run from any directory: python Media/Branding/generate.py.
No downloaded art, font files, or proprietary addon assets are used.
"""
from pathlib import Path
from math import exp, hypot
from xml.sax.saxutils import escape
import argparse
import struct

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SS = 4


def color(hex_value, alpha=255):
    return tuple(int(hex_value[i:i + 2], 16) for i in (1, 3, 5)) + (alpha,)


class Artwork:
    """The same authored geometry feeds editable SVG and antialiased TGA."""
    def __init__(self, width, height, label):
        self.width, self.height = width, height
        self.image = Image.new("RGBA", (width * SS, height * SS))
        self.draw = ImageDraw.Draw(self.image)
        self.svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">',
                    f'<title>{escape(label)}</title>',
                    '<desc>Original CarGOUI geometric artwork: blue arcane light, gold navigation ornament, and a cargo cube.</desc>']

    def polygon(self, points, fill, outline=None, width=1):
        coords = [(round(x * SS), round(y * SS)) for x, y in points]
        self.draw.polygon(coords, fill=color(fill))
        if outline:
            self.draw.line(coords + [coords[0]], fill=color(outline), width=round(width * SS), joint="curve")
        values = " ".join(f"{x},{y}" for x, y in points)
        stroke = f' stroke="{outline}" stroke-width="{width}"' if outline else ""
        self.svg.append(f'<polygon points="{values}" fill="{fill}"{stroke}/>')

    def line(self, points, fill, width=1, alpha=255):
        self.draw.line([(round(x * SS), round(y * SS)) for x, y in points], fill=color(fill, alpha),
                       width=max(1, round(width * SS)), joint="curve")
        values = " ".join(f"{x},{y}" for x, y in points)
        self.svg.append(f'<polyline points="{values}" fill="none" stroke="{fill}" stroke-width="{width}" stroke-opacity="{alpha / 255:.3f}" stroke-linejoin="round"/>')

    def ring(self, box, fill, width=1, alpha=255):
        self.draw.ellipse(tuple(round(v * SS) for v in box), outline=color(fill, alpha), width=round(width * SS))
        x1, y1, x2, y2 = box
        self.svg.append(f'<ellipse cx="{(x1+x2)/2}" cy="{(y1+y2)/2}" rx="{(x2-x1)/2}" ry="{(y2-y1)/2}" fill="none" stroke="{fill}" stroke-width="{width}" stroke-opacity="{alpha / 255:.3f}"/>')

    def save(self, name):
        target = self.image.resize((self.width, self.height), Image.Resampling.LANCZOS)
        # Explicit uncompressed true-color TGA, 32-bit BGRA, top-left origin.
        header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, self.width, self.height, 32, 0x28)
        (ROOT / f"{name}.tga").write_bytes(header + target.tobytes("raw", "BGRA"))
        (ROOT / f"{name}.svg").write_text("\n".join(self.svg + ["</svg>"]) + "\n", encoding="utf-8")
        return target


def make_header():
    art = Artwork(1024, 128, "CarGOUI Options header background")
    # A near-black/navy field with a quiet blue light beneath the wordmark.
    for y in range(128):
        for x in range(1024):
            halo = exp(-(((x - 210) / 350) ** 2 + ((y - 65) / 75) ** 2))
            rgb = (round(6 + halo * 3), round(12 + halo * 10), round(20 + halo * 17))
            art.draw.rectangle((x * SS, y * SS, (x + 1) * SS - 1, (y + 1) * SS - 1), fill=rgb + (255,))
    art.svg += ['<defs><radialGradient id="navy"><stop stop-color="#091625"/><stop offset="1" stop-color="#060c14"/></radialGradient></defs>',
                '<rect width="1024" height="128" fill="url(#navy)"/>']
    gold, blue = "#9f8050", "#3b718b"
    # Open corner brackets and thin horizontal rails leave the title uncluttered.
    for points in [((4, 42), (4, 12), (30, 12), (40, 4), (173, 4)),
                   ((4, 88), (4, 116), (30, 116), (40, 124), (1000, 124), (1020, 104)),
                   ((470, 4), (988, 4), (1020, 28), (1020, 83))]:
        art.line(points, gold, 1)
    art.line(((176, 4), (330, 4), (350, 13), (380, 13), (400, 4), (466, 4)), blue, 1)
    art.line(((487, 116), (650, 116), (675, 106), (976, 106)), blue, 1, 135)
    art.line(((625, 22), (808, 22), (838, 12), (965, 12), (1008, 43)), blue, 1, 150)
    # Small navigation diamonds, with sparse bright tips.
    for x, y, size in ((450, 4, 4), (671, 116, 4), (988, 12, 5)):
        art.polygon(((x, y-size), (x+size, y), (x, y+size), (x-size, y)), "#183849", "#bd9c60", 1)
    for x in (693, 706, 719):
        art.line(((x, 116), (x + 6, 111)), gold, 1, 160)
    return art.save("header")


def make_emblem():
    art = Artwork(128, 128, "CarGOUI arcane cargo compass emblem")
    gold, light, blue = "#ba9557", "#f2d496", "#60bee6"
    # Faceted compass frame: deliberate gaps suggest movement, not a solid badge.
    art.ring((20, 20, 108, 108), "#15384e", 1)
    art.ring((25, 25, 103, 103), "#284955", 1)
    for points in [((31, 43), (37, 32), (53, 20), (61, 12)),
                   ((67, 12), (75, 20), (91, 32), (98, 46)),
                   ((30, 82), (39, 98), (54, 105), (61, 116)),
                   ((67, 116), (74, 105), (90, 98), (98, 82))]:
        art.line(points, gold, 2)
    # Gold swept wings double as small directional arrow rails.
    for side in (-1, 1):
        def pts(values): return [(64 + side*x, y) for x, y in values]
        art.polygon(pts(((26, 53), (45, 45), (56, 46), (44, 53), (36, 69), (25, 76))), "#183644", gold, 1)
        art.line(pts(((31, 63), (43, 56), (55, 53))), light, 1)
        art.line(pts(((36, 77), (46, 67), (55, 63))), "#498cab", 1)
    # The original cargo cube is the identity; the split top suggests a lid.
    art.polygon(((64, 31), (88, 45), (64, 60), (40, 45)), "#214b65", light, 1.4)
    art.polygon(((40, 45), (64, 60), (64, 89), (40, 73)), "#0f2a40", gold, 1.4)
    art.polygon(((64, 60), (88, 45), (88, 73), (64, 89)), "#174159", gold, 1.4)
    art.line(((51, 38), (75, 53), (75, 70)), blue, 1.6)
    art.line(((51, 52), (51, 65)), "#68bdcf", 1.3)
    art.line(((64, 64), (64, 82)), "#e2bd76", 1.4)
    art.polygon(((64, 4), (68, 11), (64, 18), (60, 11)), "#70caef", light, 1)
    art.polygon(((64, 108), (68, 117), (64, 124), (60, 117)), "#2d6a88", gold, 1)
    art.line(((61, 98), (64, 102), (67, 98)), blue, 1.5)
    return art.save("emblem")


def make_glow():
    art = Artwork(128, 128, "CarGOUI soft blue title radiance")
    # Transparent radial radiance; runtime stretches it beneath the native wordmark.
    for y in range(128):
        for x in range(128):
            radius = hypot((x - 63.5) / 64, (y - 63.5) / 64)
            alpha = round(100 * max(0, 1 - radius) ** 2)
            art.draw.rectangle((x*SS, y*SS, (x+1)*SS-1, (y+1)*SS-1), fill=(66, 172, 236, alpha))
    art.svg += ['<defs><radialGradient id="glow"><stop stop-color="#42acec" stop-opacity="0.392"/><stop offset="1" stop-color="#42acec" stop-opacity="0"/></radialGradient></defs>',
                '<circle cx="64" cy="64" r="64" fill="url(#glow)"/>']
    return art.save("glow")


def validate_assets():
    for name, expected in (("header", (1024, 128)), ("emblem", (128, 128)), ("glow", (128, 128))):
        raw = (ROOT / f"{name}.tga").read_bytes()
        _, color_map, image_type, _, _, _, _, _, width, height, depth, descriptor = struct.unpack("<BBBHHBHHHHBB", raw[:18])
        assert color_map == 0 and image_type == 2, f"{name}: expected uncompressed true color"
        assert (width, height) == expected and all(n & (n - 1) == 0 for n in expected), f"{name}: dimensions"
        assert depth == 32 and descriptor == 0x28, f"{name}: expected 32-bit alpha, top-left origin"
        assert len(raw) == 18 + width * height * 4, f"{name}: image payload length"
        with Image.open(ROOT / f"{name}.tga") as decoded:
            assert decoded.mode == "RGBA" and decoded.size == expected, f"{name}: decode"
            if name != "header":
                assert decoded.getpixel((0, 0))[3] == 0, f"{name}: transparent corners"
        assert (ROOT / f"{name}.svg").read_text(encoding="utf-8").startswith('<svg '), f"{name}: vector source"
    print("Verified 3 uncompressed, 32-bit, power-of-two TGA assets and SVG sources.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing assets without regenerating them.")
    if not parser.parse_args().check:
        make_header()
        make_emblem()
        make_glow()
        print("Generated header, emblem, and glow SVG/TGA assets.")
    validate_assets()
