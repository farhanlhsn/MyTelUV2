"""Generates the splash and launcher images from assets/images/telyu.png.

Run from the repository root:  python3 -I mobile/tool/brand_assets.py

The Telkom University logo is the symbol (red book over the grey U) above the words
"Telkom University". At icon size the words are unreadable, so the splash and the launcher use
the symbol alone, padded so Android's circular masks never cut it.
"""
from pathlib import Path

from PIL import Image, ImageDraw

MOBILE = Path(__file__).resolve().parent.parent
RES = MOBILE / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
WHITE = (255, 255, 255, 255)

# Shared with lib/pages/splash_page.dart: circle and symbol sizes of the splash, in dp.
SPLASH_ICON_DP = 240      # Android 12 splash icon canvas (with an icon background)
SPLASH_CIRCLE_DP = 160    # visible white circle
SPLASH_SYMBOL_DP = 96     # symbol height inside it
LAUNCHER_DP = 108         # adaptive icon canvas
LAUNCHER_SYMBOL_DP = 52   # fits the 66 dp safe circle
LEGACY_DP = 48            # pre-26 launcher icon
LEGACY_SYMBOL_DP = 28


def symbol() -> Image.Image:
    """The book and the U, cropped tight: every row above the first gap after the U."""
    logo = Image.open(MOBILE / "assets/images/telyu.png").convert("RGBA")
    alpha = logo.split()[3].point(lambda v: 255 if v > 20 else 0)
    w, h = logo.size
    filled = [alpha.crop((0, y, w, y + 1)).getbbox() is not None for y in range(h)]
    # bands of filled rows: book, U, "Telkom", "University"; the symbol is the first two
    bands, y = [], 0
    while y < h:
        if filled[y]:
            start = y
            while y < h and filled[y]:
                y += 1
            bands.append((start, y))
        y += 1
    top, bottom = bands[0][0], bands[1][1]
    part = logo.crop((0, top, w, bottom))
    return part.crop(part.split()[3].point(lambda v: 255 if v > 20 else 0).getbbox())


def fit(sym: Image.Image, height: int) -> Image.Image:
    width = round(sym.width * height / sym.height)
    return sym.resize((width, height), Image.LANCZOS)


def centered(size: int, sym: Image.Image, sym_h: int, circle: int = 0) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if circle:
        off = (size - circle) // 2
        ImageDraw.Draw(canvas).ellipse((off, off, off + circle - 1, off + circle - 1), fill=WHITE)
    s = fit(sym, sym_h)
    canvas.alpha_composite(s, ((size - s.width) // 2, (size - s.height) // 2))
    return canvas


def main() -> None:
    sym = symbol()
    fit(sym, 600).save(MOBILE / "assets/images/telyu_symbol.png")
    for name, scale in DENSITIES.items():
        px = lambda dp: round(dp * scale)  # noqa: E731
        drawable, mipmap = RES / f"drawable-{name}", RES / f"mipmap-{name}"
        drawable.mkdir(exist_ok=True)
        centered(px(SPLASH_ICON_DP), sym, px(SPLASH_SYMBOL_DP)).save(drawable / "splash_icon.png")
        centered(px(SPLASH_CIRCLE_DP), sym, px(SPLASH_SYMBOL_DP), px(SPLASH_CIRCLE_DP)).save(
            drawable / "splash_mark.png")
        centered(px(LAUNCHER_DP), sym, px(LAUNCHER_SYMBOL_DP)).save(
            drawable / "ic_launcher_foreground.png")
        centered(px(LEGACY_DP), sym, px(LEGACY_SYMBOL_DP), px(LEGACY_DP)).save(
            mipmap / "ic_launcher.png")
    # Sources for flutter_launcher_icons (pubspec.yaml), so a rerun keeps the padding
    icon_dir = MOBILE / "assets/icon"
    icon_dir.mkdir(exist_ok=True)
    centered(1024, sym, round(1024 * LAUNCHER_SYMBOL_DP / LAUNCHER_DP)).save(
        icon_dir / "launcher_foreground.png")
    centered(1024, sym, round(1024 * LEGACY_SYMBOL_DP / LEGACY_DP), 1024).save(
        icon_dir / "launcher_legacy.png")


if __name__ == "__main__":
    main()
