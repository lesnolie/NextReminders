"""Generate the settings window textures in NextReminders/Media (white, tinted in game).

Shapes are drawn at 8x and downsampled so edges stay smooth on high-DPI screens. Run after changing a shape:
    python tools/make_ui_textures.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parents[1] / "NextReminders" / "Media"
SS = 8


def save(image, name):
    image.save(OUT / f"ui_{name}.tga")


def supersampled(size, draw):
    big = Image.new("L", (size * SS, size * SS), 0)
    draw(ImageDraw.Draw(big), size * SS)
    alpha = big.resize((size, size), Image.LANCZOS)
    image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    image.putalpha(alpha)
    return image


# Nine-slice sources. Corners are exact quarter circles of 64 texels, so any radius up to half the height works.
def round_rect(d, s):
    d.rounded_rectangle((0, 0, s - 1, s - 1), radius=s // 4, fill=255)


def circle(d, s):
    d.ellipse((0, 0, s - 1, s - 1), fill=255)


def shadow():
    size = 256
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((64, 72, 192, 200), radius=40, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(22))
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    image.putalpha(mask)
    return image


def stroke(d, points, width):
    d.line(points, fill=255, width=width, joint="curve")
    r = width // 2
    for x, y in (points[0], points[-1]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)


def icon(name, paint):
    def draw(d, s):
        u = s / 64
        paint(d, u, int(6 * u))
    save(supersampled(32, draw), "icon_" + name)


def import_icon(d, u, w):
    stroke(d, [(32 * u, 10 * u), (32 * u, 38 * u)], w)
    stroke(d, [(20 * u, 27 * u), (32 * u, 39 * u), (44 * u, 27 * u)], w)
    stroke(d, [(12 * u, 40 * u), (12 * u, 52 * u), (52 * u, 52 * u), (52 * u, 40 * u)], w)


def settings_icon(d, u, w):
    for y, knob in ((18, 40), (32, 22), (46, 34)):
        stroke(d, [(10 * u, y * u), (54 * u, y * u)], w)
        r = 7 * u
        d.ellipse((knob * u - r, y * u - r, knob * u + r, y * u + r), fill=255)


def play_icon(d, u, w):
    d.polygon([(20 * u, 12 * u), (52 * u, 32 * u), (20 * u, 52 * u)], fill=255)


def pause_icon(d, u, w):
    d.rounded_rectangle((16 * u, 12 * u, 27 * u, 52 * u), radius=3 * u, fill=255)
    d.rounded_rectangle((37 * u, 12 * u, 48 * u, 52 * u), radius=3 * u, fill=255)


def stop_icon(d, u, w):
    d.rounded_rectangle((14 * u, 14 * u, 50 * u, 50 * u), radius=6 * u, fill=255)


def close_icon(d, u, w):
    stroke(d, [(18 * u, 18 * u), (46 * u, 46 * u)], w)
    stroke(d, [(46 * u, 18 * u), (18 * u, 46 * u)], w)


def chevron_icon(d, u, w):
    stroke(d, [(18 * u, 26 * u), (32 * u, 40 * u), (46 * u, 26 * u)], w)


def check_icon(d, u, w):
    stroke(d, [(14 * u, 33 * u), (27 * u, 46 * u), (50 * u, 20 * u)], w)


def sound_icon(d, u, w):
    d.polygon([(10 * u, 24 * u), (22 * u, 24 * u), (34 * u, 12 * u), (34 * u, 52 * u), (22 * u, 40 * u), (10 * u, 40 * u)], fill=255)
    d.arc((26 * u, 20 * u, 50 * u, 44 * u), -50, 50, fill=255, width=w)


def broom_icon(d, u, w):
    stroke(d, [(46 * u, 10 * u), (32 * u, 30 * u)], w)
    d.polygon([(22 * u, 28 * u), (40 * u, 38 * u), (32 * u, 54 * u), (10 * u, 46 * u)], fill=255)


def power_icon(d, u, w):
    d.arc((12 * u, 14 * u, 52 * u, 54 * u), -55, 235, fill=255, width=w)
    stroke(d, [(32 * u, 8 * u), (32 * u, 30 * u)], w)


LOGO_SOURCE = Path(__file__).resolve().parent / "assets" / "logo_source.png"


def logo():
    """Cut the black app icon out of its white backdrop and scale it to 128 (shown at 44, also the addon-list icon)."""
    import numpy as np
    src = Image.open(LOGO_SOURCE).convert("RGB")
    dark = np.asarray(src).astype(int).sum(axis=2) < 200
    ys, xs = np.where(dark)
    top, bottom, left, right = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    dark = dark[top:bottom, left:right]
    # The square is convex: every row is solid between its first and last dark pixel, which keeps the silver N opaque.
    mask = np.zeros(dark.shape, dtype=np.uint8)
    for y, row in enumerate(dark):
        hits = np.flatnonzero(row)
        if hits.size:
            mask[y, hits[0]:hits[-1] + 1] = 255
    side = max(mask.shape)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    icon_rgba = src.crop((left, top, right, bottom)).convert("RGBA")
    icon_rgba.putalpha(Image.fromarray(mask, "L"))
    canvas.alpha_composite(icon_rgba, ((side - mask.shape[1]) // 2, (side - mask.shape[0]) // 2))
    save(canvas.resize((128, 128), Image.LANCZOS), "logo")


# Textures are drawn about 2x their on-screen size: the client scales addon textures without mipmaps, so a much
# larger source shrunk at draw time shimmers and looks jagged. One rounded square per corner radius, one circle per size.
RADII = (2, 3, *range(11, 25), 27, 28, 35, 36)  # every radius Theme.lua draws (fill is radius-1)
CIRCLES = (32, 64, 128)


def pow2(n):
    size = 8
    while size < n:
        size *= 2
    return size


def round_for(radius):
    corner = 2 * radius
    size = pow2(2 * corner)

    def draw(d, s):
        k = s / size
        d.rounded_rectangle((0, 0, s - 1, s - 1), radius=corner * k, fill=255)
    return supersampled(size, draw)


if __name__ == "__main__":
    for old in OUT.glob("ui_*.tga"):
        old.unlink()
    for r in RADII:
        save(round_for(r), f"round_{r}")
    for size in CIRCLES:
        save(supersampled(size, circle), f"circle_{size}")
    save(shadow(), "shadow")
    for name, paint in (("import", import_icon), ("settings", settings_icon), ("play", play_icon), ("pause", pause_icon),
                        ("stop", stop_icon), ("close", close_icon), ("chevron", chevron_icon), ("check", check_icon),
                        ("sound", sound_icon), ("clean", broom_icon), ("power", power_icon)):
        icon(name, paint)
    logo()
    print("ui textures written to", OUT)
