"""Draws the po0-clash mark and writes every icon the three native apps ship.

Run from the repository root: python tool/make_icons.py (needs Pillow).
The mark is a lowercase p built from two flat shapes, a cream stem and a dusty-rose bowl, on a
haze-blue tile (a Morandi palette); where the shapes overlap a third tone shows. Geometry is on a 1024 grid.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

GRID = 1024
SCALE = 4
STEM = (282, 224, 432, 800)
BOWL, BOWL_RADIUS, BOWL_HOLE = (529, 430), 206, 86

PAPER = (137, 155, 166)
STEM_TONE, BOWL_TONE, OVERLAP_TONE = (240, 234, 224), (214, 178, 168), (190, 150, 142)
RUNNING, TUN, STOPPED = (125, 146, 160), (143, 164, 140), (158, 153, 146)

ROOT = Path(__file__).resolve().parent.parent
ANDROID_RES = ROOT / "apps/android/app/src/main/res"
WINDOWS_ICONS = ROOT / "apps/windows/src-tauri/icons"
MACOS_RES = ROOT / "apps/macos/Resources"
ICO_SIZES = [16, 20, 24, 32, 40, 48, 64]


def shapes(size, zoom):
    """Alpha masks of the stem and the bowl, scaled by `zoom` about the canvas centre."""
    big = GRID * SCALE

    def at(value):
        return ((value - GRID / 2) * zoom + GRID / 2) * SCALE

    stem = Image.new("L", (big, big), 0)
    x0, y0, x1, y1 = (at(v) for v in STEM)
    ImageDraw.Draw(stem).rounded_rectangle((x0, y0, x1, y1), radius=(x1 - x0) / 2, fill=255)
    bowl = Image.new("L", (big, big), 0)
    cx, cy, r = at(BOWL[0]), at(BOWL[1]), BOWL_RADIUS * zoom * SCALE
    ImageDraw.Draw(bowl).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    return stem.resize((size, size), Image.LANCZOS), bowl.resize((size, size), Image.LANCZOS)


def mark(size, zoom, tones=(STEM_TONE, BOWL_TONE, OVERLAP_TONE)):
    """The three-tone mark on a transparent canvas."""
    stem, bowl = shapes(size, zoom)
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for tone, mask in zip(tones, (stem, bowl, ImageChops.multiply(stem, bowl))):
        image.paste(Image.new("RGBA", (size, size), tone + (255,)), (0, 0), mask)
    return image


def tile(size, margin, radius, zoom):
    """The app icon: the mark on a rounded tile."""
    big = size * SCALE
    shape = Image.new("L", (big, big), 0)
    inset = margin * big
    ImageDraw.Draw(shape).rounded_rectangle((inset, inset, big - inset, big - inset), radius=radius * big, fill=255)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(Image.new("RGBA", (size, size), PAPER + (255,)), (0, 0), shape.resize((size, size), Image.LANCZOS))
    icon.alpha_composite(mark(size, zoom))
    return icon


def glyph(size, colour, zoom=1.5):
    """A one-colour mark for trays and the menu bar; the bowl gets a counter so it still reads as a p."""
    big = GRID * SCALE
    stem, bowl = shapes(big, zoom)
    mask = ImageChops.lighter(stem, bowl)
    half = big / 2
    cx, cy = ((BOWL[0] - GRID / 2) * zoom * SCALE + half, (BOWL[1] - GRID / 2) * zoom * SCALE + half)
    r = BOWL_HOLE * zoom * SCALE
    ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=0)
    image = Image.new("RGBA", (size, size), colour + (0,))
    image.putalpha(mask.resize((size, size), Image.LANCZOS))
    return image


def save_ico(path, render, sizes):
    images = [render(size) for size in sizes]
    images[-1].save(path, format="ICO", sizes=[(s, s) for s in sizes], append_images=images[:-1])


def main():
    tile(1024, 100 / 1024, 185 / 1024, 0.9).save(MACOS_RES / "AppIcon.png")
    for suffix, size in (("", 18), ("@2x", 36), ("@3x", 54)):
        glyph(size, STOPPED).save(MACOS_RES / f"MenuBarIcon{suffix}.png")

    windows = lambda size: tile(size, 0.02, 0.215, 1.08)
    windows(512).save(WINDOWS_ICONS / "icon.png")
    save_ico(WINDOWS_ICONS / "icon.ico", windows, ICO_SIZES + [96, 128, 256])
    save_ico(WINDOWS_ICONS / "tray/proxy.ico", lambda s: glyph(s, RUNNING), ICO_SIZES)
    save_ico(WINDOWS_ICONS / "tray/tun.ico", lambda s: glyph(s, TUN), ICO_SIZES)
    save_ico(WINDOWS_ICONS / "tray/stopped.ico", lambda s: glyph(s, STOPPED), ICO_SIZES)

    for density, size in (("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)):
        folder = ANDROID_RES / f"mipmap-{density}"
        Image.new("RGB", (size, size), PAPER).save(folder / "ic_launcher_background.png")
        mark(size, 0.62).save(folder / "ic_launcher_foreground.png")


if __name__ == "__main__":
    main()
