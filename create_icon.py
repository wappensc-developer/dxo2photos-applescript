#!/usr/bin/env python3
"""
Creates dxo2photos.icns — icon for the DxO PhotoLab app bundle.

Visual: blue gradient background, white camera body, gold 5-pointed star.
Output: dxo2photos.icns (next to this script).
"""

import math
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Error: Pillow not found. Run: pip install 'Pillow>=9.0.0'", file=sys.stderr)
    sys.exit(1)

# Colours
BG_TOP    = (35, 120, 255, 255)
BG_BOTTOM = (10,  55, 185, 255)
CAMERA    = (255, 255, 255, 235)
LENS_DARK = ( 15,  65, 185, 255)
LENS_RING = (255, 255, 255, 215)
STAR_GOLD = (255, 200,   0, 255)

ICON_SPECS = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]


def star_polygon(cx, cy, outer_r, inner_r, points=5):
    coords = []
    for i in range(points * 2):
        angle = math.pi / points * i - math.pi / 2
        r = outer_r if i % 2 == 0 else inner_r
        coords.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    return coords


def create_icon(s):
    img = Image.new("RGBA", (s, s), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # Vertical gradient background
    for y in range(s):
        t = y / max(s - 1, 1)
        r = round(BG_TOP[0] + t * (BG_BOTTOM[0] - BG_TOP[0]))
        g = round(BG_TOP[1] + t * (BG_BOTTOM[1] - BG_TOP[1]))
        b = round(BG_TOP[2] + t * (BG_BOTTOM[2] - BG_TOP[2]))
        draw.line([(0, y), (s - 1, y)], fill=(r, g, b, 255))

    # Camera body (white rounded rectangle, lower 55 % of icon)
    pad       = s * 0.12
    cam_top   = s * 0.38
    cam_bot   = s * 0.84
    cam_r     = max(2, round(s * 0.06))
    draw.rounded_rectangle(
        [round(pad), round(cam_top), round(s - pad), round(cam_bot)],
        radius=cam_r, fill=CAMERA,
    )

    # Viewfinder bump (top-left of camera)
    bump_w  = s * 0.21
    bump_h  = s * 0.09
    bump_cx = s * 0.37
    bump_r  = max(1, round(s * 0.03))
    draw.rounded_rectangle(
        [round(bump_cx - bump_w / 2), round(cam_top - bump_h),
         round(bump_cx + bump_w / 2), round(cam_top + 1)],
        radius=bump_r, fill=CAMERA,
    )

    # Lens: white ring + dark blue centre
    lens_cx = s * 0.50
    lens_cy = (cam_top + cam_bot) / 2 + s * 0.02
    lens_r  = s * 0.155
    ring_w  = max(2, round(s / 42))
    draw.ellipse(
        [round(lens_cx - lens_r), round(lens_cy - lens_r),
         round(lens_cx + lens_r), round(lens_cy + lens_r)],
        fill=LENS_RING,
    )
    inner = lens_r - ring_w * 2.5
    if inner > 0:
        draw.ellipse(
            [round(lens_cx - inner), round(lens_cy - inner),
             round(lens_cx + inner), round(lens_cy + inner)],
            fill=LENS_DARK,
        )

    # Gold 5-pointed star (upper right)
    star_cx    = s * 0.73
    star_cy    = s * 0.25
    star_outer = s * 0.205
    star_inner = star_outer * 0.42
    coords = star_polygon(star_cx, star_cy, star_outer, star_inner)
    draw.polygon(coords, fill=STAR_GOLD)

    # Rounded mask (clip corners)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, s - 1, s - 1], radius=s // 5, fill=255,
    )
    img.putalpha(mask)

    return img


def main():
    here     = Path(__file__).parent
    iconset  = here / "dxo2photos.iconset"
    icns_out = here / "dxo2photos.icns"

    iconset.mkdir(exist_ok=True)

    for logical, scale in ICON_SPECS:
        px     = logical * scale
        suffix = "" if scale == 1 else f"@{scale}x"
        create_icon(px).save(iconset / f"icon_{logical}x{logical}{suffix}.png")

    subprocess.run(
        ["iconutil", "--convert", "icns", str(iconset), "--output", str(icns_out)],
        check=True,
    )
    shutil.rmtree(iconset)
    print(f"Icon created: {icns_out}")


if __name__ == "__main__":
    main()
