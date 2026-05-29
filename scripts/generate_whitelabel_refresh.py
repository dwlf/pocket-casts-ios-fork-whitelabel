#!/usr/bin/env python3
"""Generate neutral pull-to-refresh spinner arcs for the Whitelabel build.

Idempotent: re-running produces byte-identical output as long as the
constants below are unchanged.

Outputs (template-rendered, so only the alpha channel matters — the
runtime tint colour is applied by CustomRefreshControl):

    podcasts/CommonImages.xcassets/refresh_inner_whitelabel.imageset/
        refresh_inner_whitelabel@2x.png   (46x46)
        refresh_inner_whitelabel@3x.png   (69x69)
    podcasts/CommonImages.xcassets/refresh_outer_whitelabel.imageset/
        refresh_outer_whitelabel@2x.png   (46x46)
        refresh_outer_whitelabel@3x.png   (69x69)

The upstream refresh_inner / refresh_outer assets are the Pocket Casts
spinner glyph. These replacements are two plain concentric ring-arcs —
brand-free, but they preserve the two-ring rotation animation
(CustomRefreshControl spins inner and outer at different speeds). The
branded private fork may replace these assets entirely.
"""

from pathlib import Path

from PIL import Image, ImageDraw

POINT_SIZE = 23  # matches upstream refresh assets (46@2x, 69@3x)
WHITE = (255, 255, 255, 255)

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG = REPO_ROOT / "podcasts" / "CommonImages.xcassets"

CONTENTS_JSON = """{{
  "images" : [
    {{
      "idiom" : "universal",
      "scale" : "1x"
    }},
    {{
      "idiom" : "universal",
      "filename" : "{name}@2x.png",
      "scale" : "2x"
    }},
    {{
      "idiom" : "universal",
      "filename" : "{name}@3x.png",
      "scale" : "3x"
    }}
  ],
  "info" : {{
    "version" : 1,
    "author" : "xcode"
  }}
}}
"""


def draw_arc(scale: int, radius_fraction: float, stroke_pt: float, sweep_deg: float, start_deg: float) -> Image.Image:
    """Render a single ring-arc on a transparent square canvas.

    Args:
        scale: Asset scale factor (2 or 3); canvas side is POINT_SIZE * scale.
        radius_fraction: Ring radius as a fraction of half the canvas side.
        stroke_pt: Arc stroke width in points (multiplied by scale).
        sweep_deg: Arc length in degrees (a gap of 360 - sweep is left open).
        start_deg: Arc start angle in degrees, clockwise from 3 o'clock.

    Returns:
        An RGBA image with the arc drawn opaque-white on transparent.
    """
    side = POINT_SIZE * scale
    image = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    stroke = max(1, round(stroke_pt * scale))
    inset = stroke / 2 + (side / 2) * (1 - radius_fraction)
    box = (inset, inset, side - inset, side - inset)
    draw.arc(box, start=start_deg, end=start_deg + sweep_deg, fill=WHITE, width=stroke)
    return image


def write_imageset(name: str, radius_fraction: float, stroke_pt: float, sweep_deg: float, start_deg: float) -> None:
    """Create the imageset directory, render @2x/@3x PNGs, and write Contents.json."""
    imageset = CATALOG / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    for scale in (2, 3):
        image = draw_arc(scale, radius_fraction, stroke_pt, sweep_deg, start_deg)
        image.save(imageset / f"{name}@{scale}x.png")
    (imageset / "Contents.json").write_text(CONTENTS_JSON.format(name=name))


def main() -> None:
    # Outer ring: larger radius, 270deg sweep starting top-right.
    write_imageset("refresh_outer_whitelabel", radius_fraction=0.92, stroke_pt=2.0, sweep_deg=270, start_deg=-45)
    # Inner ring: smaller radius, 210deg sweep starting bottom-left, offset so
    # the two rings read as distinct when rotating at different speeds.
    write_imageset("refresh_inner_whitelabel", radius_fraction=0.55, stroke_pt=2.0, sweep_deg=210, start_deg=135)


if __name__ == "__main__":
    main()
