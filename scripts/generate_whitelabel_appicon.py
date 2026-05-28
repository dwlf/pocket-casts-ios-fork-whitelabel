#!/usr/bin/env python3
"""Generate the neutral Whitelabel app icon (1024x1024 PNG).

Idempotent: re-running produces byte-identical output as long as the
constants below and the source font on disk are unchanged.

Output: podcasts/AppIcon.xcassets/AppIcon-Whitelabel.appiconset/AppIcon-Whitelabel-1024.png

The icon is intentionally minimal: dark slate background with a
centered "Whitelabel" wordmark in white. Matches the splash + nav-bar
Text-swap aesthetic shipped in Stage 3.B. The branded private fork is
expected to replace this asset entirely; this is a placeholder that
clearly reads as non-Pocket-Casts on the home screen.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
BACKGROUND = (44, 46, 58, 255)  # #2C2E3A slate
TEXT_COLOR = (255, 255, 255, 255)
TEXT = "Whitelabel"
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_SIZE = 140

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_PATH = (
    REPO_ROOT
    / "podcasts"
    / "AppIcon.xcassets"
    / "AppIcon-Whitelabel.appiconset"
    / "AppIcon-Whitelabel-1024.png"
)


def main() -> None:
    image = Image.new("RGBA", (SIZE, SIZE), BACKGROUND)
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)

    # Pillow's textbbox returns (left, top, right, bottom) for the rendered
    # glyph extents. Center horizontally by extent width; center vertically
    # using the bbox top/bottom so descenders don't pull the baseline off.
    left, top, right, bottom = draw.textbbox((0, 0), TEXT, font=font)
    text_width = right - left
    text_height = bottom - top
    x = (SIZE - text_width) // 2 - left
    y = (SIZE - text_height) // 2 - top

    draw.text((x, y), TEXT, font=font, fill=TEXT_COLOR)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT_PATH, "PNG", optimize=True)
    print(f"wrote {OUTPUT_PATH.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
