#!/usr/bin/env python3
"""Render real Footing Simulator captures into social-ready device mockups."""

import base64
import json
import pathlib
import subprocess
import sys

from build import brandmark, font_css

HERE = pathlib.Path(__file__).resolve().parent
CAPTURES = HERE / "app-captures"
OUT = HERE / "out" / "app"
BUILD = HERE / "build" / "app"
CSS = HERE / "app-assets.css"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

EXPORTS = [
    {
        "name": "jordan-today-feed",
        "source": "jordan-today-2026-07-10.png",
        "width": 1080,
        "height": 1350,
        "class_name": "feed",
        "variables": {
            "brand-top": "54px",
            "brand-left": "66px",
            "device-top": "142px",
            "device-width": "800px",
            "bezel": "16px",
        },
    },
    {
        "name": "jordan-today-story",
        "source": "jordan-today-2026-07-10.png",
        "width": 1080,
        "height": 1920,
        "class_name": "story",
        "variables": {
            "brand-top": "70px",
            "brand-left": "66px",
            "device-top": "176px",
            "device-width": "844px",
            "bezel": "17px",
        },
    },
    {
        "name": "jordan-pulse-feed",
        "source": "jordan-pulse-protein-gap.png",
        "width": 1080,
        "height": 1350,
        "class_name": "feed",
        "variables": {
            "brand-top": "54px",
            "brand-left": "66px",
            "device-top": "142px",
            "device-width": "800px",
            "bezel": "16px",
        },
    },
    {
        "name": "jordan-pulse-story",
        "source": "jordan-pulse-protein-gap.png",
        "width": 1080,
        "height": 1920,
        "class_name": "story",
        "variables": {
            "brand-top": "70px",
            "brand-left": "66px",
            "device-top": "176px",
            "device-width": "844px",
            "bezel": "17px",
        },
    },
    {
        "name": "jordan-analytics-feed",
        "source": "jordan-analytics-30-days.png",
        "width": 1080,
        "height": 1350,
        "class_name": "feed",
        "variables": {
            "brand-top": "54px",
            "brand-left": "66px",
            "device-top": "142px",
            "device-width": "800px",
            "bezel": "16px",
        },
    },
    {
        "name": "jordan-analytics-story",
        "source": "jordan-analytics-30-days.png",
        "width": 1080,
        "height": 1920,
        "class_name": "story",
        "variables": {
            "brand-top": "70px",
            "brand-left": "66px",
            "device-top": "176px",
            "device-width": "844px",
            "bezel": "17px",
        },
    },
]


def data_uri(path: pathlib.Path) -> str:
    encoded = base64.b64encode(path.read_bytes()).decode()
    return f"data:image/png;base64,{encoded}"


def render_html(export: dict, source: pathlib.Path) -> str:
    custom_properties = [
        f"--canvas-width:{export['width']}px",
        f"--canvas-height:{export['height']}px",
    ]
    custom_properties.extend(
        f"--{key}:{value}" for key, value in export["variables"].items()
    )
    variables = ";".join(custom_properties)
    return f"""<!doctype html>
<meta charset="utf-8">
<style>{font_css()}</style>
<style>:root{{{variables}}}</style>
<link rel="stylesheet" href="{CSS.as_uri()}">
<body>
  <main class="asset {export['class_name']}">
    <div class="brand">{brandmark(48)}<span>Footing</span></div>
    <div class="device" aria-label="Footing on iPhone">
      <div class="screen"><img src="{data_uri(source)}" alt=""></div>
    </div>
  </main>
</body>
"""


def main() -> int:
    if not pathlib.Path(CHROME).exists():
        sys.exit(f"Google Chrome not found at {CHROME}")

    BUILD.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    manifest = {
        "source_type": "real Footing iOS Simulator screenshot",
        "preservation": "The app screenshot is embedded without retouching or regenerated text.",
        "exports": [],
    }

    for export in EXPORTS:
        source = CAPTURES / export["source"]
        if not source.exists():
            sys.exit(f"Missing Simulator capture: {source}")
        html_path = BUILD / f"{export['name']}.html"
        output_path = OUT / f"{export['name']}.png"
        html_path.write_text(render_html(export, source))

        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--force-device-scale-factor=2",
                f"--window-size={export['width']},{export['height']}",
                f"--screenshot={output_path}",
                "--virtual-time-budget=1500",
                html_path.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            [
                "sips",
                "-z",
                str(export["height"]),
                str(export["width"]),
                str(output_path),
            ],
            check=True,
            capture_output=True,
        )
        manifest["exports"].append(
            {
                "path": str(output_path),
                "source": str(source),
                "width": export["width"],
                "height": export["height"],
                "format": "PNG",
            }
        )
        print(output_path)

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
