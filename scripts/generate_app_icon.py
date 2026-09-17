#!/usr/bin/env python3
"""Generate MacPower icons: PNG fallbacks plus an Icon Composer .icon package.

Apple does not bake Liquid Glass into SVG. Official path:
1. Export full-canvas layered SVGs (no background, no squircle mask).
2. Put them in an AppIcon.icon package; Icon Composer / the system apply glass.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "MacPower" / "Assets.xcassets" / "AppIcon.appiconset"
SVG_PATH = ROOT / "scripts" / "AppIcon.svg"
ICON_PACKAGE = ROOT / "AppIcon.icon"
ASSETS = ICON_PACKAGE / "Assets"

GREEN = "#1E9B57"
WHITE = "#FFFFFF"
SIZE = 1024

# Align to the battery body's visual center, not the body+cap bounding box.
BODY_W, BODY_H = 536, 292
BODY_RX = 58
BODY_X = (SIZE - BODY_W) / 2
BODY_Y = 290
CAP_GAP = 28
CAP_W, CAP_H = 50, 128
CAPSULE_H = 96
CAPSULE_GAP = 56


def geometry() -> dict[str, float]:
    x, y, w, h = BODY_X, BODY_Y, BODY_W, BODY_H
    cx = x + w + CAP_GAP
    cy = y + (h - CAP_H) / 2
    cap_r = min(CAP_W, CAP_H) / 2
    capsule_y = y + h + CAPSULE_GAP
    capsule_r = CAPSULE_H / 2
    return {
        "x": x,
        "y": y,
        "w": w,
        "h": h,
        "rx": BODY_RX,
        "cx": cx,
        "cy": cy,
        "cw": CAP_W,
        "ch": CAP_H,
        "cr": cap_r,
        "capsule_y": capsule_y,
        "capsule_r": capsule_r,
    }


def wrap_layer(inner: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  {inner}
</svg>
"""


def preview_svg(g: dict[str, float]) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  <rect width="{SIZE}" height="{SIZE}" fill="{GREEN}"/>
  <rect x="{g['x']}" y="{g['y']}" width="{g['w']}" height="{g['h']}" rx="{g['rx']}" fill="{WHITE}"/>
  <rect x="{g['cx']}" y="{g['cy']}" width="{g['cw']}" height="{g['ch']}" rx="{g['cr']}" fill="{WHITE}"/>
  <rect x="{g['x']}" y="{g['capsule_y']}" width="{g['w']}" height="{CAPSULE_H}" rx="{g['capsule_r']}" fill="{WHITE}"/>
</svg>
"""


def icon_json() -> dict:
    # #1E9B57 and a darker sibling for Dark appearance.
    green = "srgb:0.11765,0.60784,0.34118,1.00000"
    green_dark = "srgb:0.08627,0.47843,0.27059,1.00000"
    return {
        "fill": {"automatic-gradient": green},
        "fill-specializations": [
            {"appearance": "dark", "value": {"automatic-gradient": green_dark}}
        ],
        "groups": [
            {
                "name": "Glyph",
                "lighting": "individual",
                "blur-material": 0.18,
                "shadow": {"kind": "layer-color", "opacity": 0.5},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.35},
                "layers": [
                    {
                        "name": "Capsule",
                        "image-name": "03-Capsule.svg",
                        "glass": True,
                        "hidden": False,
                        "opacity": 1,
                    },
                    {
                        "name": "Battery Body",
                        "image-name": "01-BatteryBody.svg",
                        "glass": True,
                        "hidden": False,
                        "opacity": 1,
                    },
                    {
                        "name": "Battery Cap",
                        "image-name": "02-BatteryCap.svg",
                        "glass": True,
                        "hidden": False,
                        "opacity": 1,
                    },
                ],
            }
        ],
        "supported-platforms": {"squares": ["macOS"]},
    }


SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def write_icon_package(g: dict[str, float]) -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "01-BatteryBody.svg").write_text(
        wrap_layer(
            f'<rect x="{g["x"]}" y="{g["y"]}" width="{g["w"]}" height="{g["h"]}" rx="{g["rx"]}" fill="{WHITE}"/>'
        ),
        encoding="utf-8",
    )
    (ASSETS / "02-BatteryCap.svg").write_text(
        wrap_layer(
            f'<rect x="{g["cx"]}" y="{g["cy"]}" width="{g["cw"]}" height="{g["ch"]}" rx="{g["cr"]}" fill="{WHITE}"/>'
        ),
        encoding="utf-8",
    )
    (ASSETS / "03-Capsule.svg").write_text(
        wrap_layer(
            f'<rect x="{g["x"]}" y="{g["capsule_y"]}" width="{g["w"]}" height="{CAPSULE_H}" rx="{g["capsule_r"]}" fill="{WHITE}"/>'
        ),
        encoding="utf-8",
    )
    (ICON_PACKAGE / "icon.json").write_text(
        json.dumps(icon_json(), indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    g = geometry()
    ICONSET.mkdir(parents=True, exist_ok=True)
    SVG_PATH.write_text(preview_svg(g), encoding="utf-8")
    leftover = ICONSET / "AppIcon.svg"
    if leftover.exists():
        leftover.unlink()
    leftover_master = ICONSET / "icon_1024.png"
    if leftover_master.exists():
        leftover_master.unlink()
    for name, px in SIZES.items():
        subprocess.run(
            ["rsvg-convert", "-w", str(px), "-h", str(px), str(SVG_PATH), "-o", str(ICONSET / name)],
            check=True,
        )
    if (ICON_PACKAGE / "icon.json").exists():
        print(f"wrote {SVG_PATH} and {len(SIZES)} pngs; kept existing {ICON_PACKAGE}")
    else:
        write_icon_package(g)
        print(f"wrote {SVG_PATH}, {len(SIZES)} pngs, and {ICON_PACKAGE}")


if __name__ == "__main__":
    main()
