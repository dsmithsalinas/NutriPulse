#!/usr/bin/env python3
"""
Render the Instagram slide set for @tryfooting.

Why a renderer and not a design file: every slide has to hold the same tokens as
marketing/site-v2. Hand-placing them in a design tool means they drift the first
time the palette moves. Here, slides.css imports the same values the site uses,
so a token change is one edit and a re-run.

    python3 marketing/social/build.py

Output: marketing/social/out/*.png at 1080x1350 (Instagram 4:5 portrait).
Rendered at device-scale 2 through headless Chrome, then downsampled with sips,
so the type is supersampled rather than hinted at final size.

Fonts are inlined as base64 from the site's own node_modules. Chrome blocks
file:// font fetches under CORS, and a network fetch would mean the render
depends on a CDN being up.
"""

import base64
import pathlib
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
SITE = HERE.parent / "site-v2"
BUILD = HERE / "build"
OUT = HERE / "out"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1080, 1350

FONTS = [
    ("Inter Variable", "normal", "100 900", "woff2-variations",
     SITE / "node_modules/@fontsource-variable/inter/files/inter-latin-opsz-normal.woff2"),
    ("Inter Variable", "italic", "100 900", "woff2-variations",
     SITE / "node_modules/@fontsource-variable/inter/files/inter-latin-opsz-italic.woff2"),
    ("Instrument Serif", "italic", "400", "woff2",
     SITE / "node_modules/@fontsource/instrument-serif/files/instrument-serif-latin-400-italic.woff2"),
    ("Instrument Serif", "normal", "400", "woff2",
     SITE / "node_modules/@fontsource/instrument-serif/files/instrument-serif-latin-400-normal.woff2"),
]

QR_SVG = SITE / "public/testflight-qr.svg"


def font_css() -> str:
    out = []
    for family, style, weight, fmt, path in FONTS:
        if not path.exists():
            sys.exit(f"missing font: {path}\nrun `npm install` in {SITE}")
        b64 = base64.b64encode(path.read_bytes()).decode()
        out.append(
            "@font-face{font-family:'%s';font-style:%s;font-weight:%s;"
            "src:url(data:font/woff2;base64,%s) format('%s');}"
            % (family, style, weight, b64, fmt)
        )
    return "\n".join(out)


# The nav lockup from site-v2/src/App.tsx, verbatim geometry.
def brandmark(size: int = 54) -> str:
    return (
        '<svg width="%d" height="%d" viewBox="0 0 64 64">'
        '<defs>'
        '<linearGradient id="bm" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0%%" stop-color="#6366F1"/><stop offset="100%%" stop-color="#8B5CF6"/>'
        '</linearGradient>'
        '<radialGradient id="bmg" cx="0.28" cy="0.12" r="0.9">'
        '<stop offset="0%%" stop-color="#fff" stop-opacity="0.3"/>'
        '<stop offset="58%%" stop-color="#fff" stop-opacity="0"/>'
        '</radialGradient>'
        '</defs>'
        '<rect width="64" height="64" rx="14.32" fill="url(#bm)"/>'
        '<rect width="64" height="64" rx="14.32" fill="url(#bmg)"/>'
        '<g transform="translate(12.80, 12.80) scale(0.38)">'
        '<circle cx="50" cy="50" r="33" stroke="#fff" stroke-width="6" fill="none" opacity="0.24"/>'
        '<path d="M 50 17 A 33 33 0 1 1 18.99 61.29" stroke="#fff" stroke-width="6" '
        'stroke-linecap="round" fill="none"/>'
        '<circle cx="18.99" cy="61.29" r="7.5" fill="#fff"/>'
        '</g></svg>' % (size, size)
    )


def lockup() -> str:
    return '<div class="brand">%s<span>Footing</span></div>' % brandmark()


def foot(left: str = "tryfooting.app", right: str = "@tryfooting") -> str:
    return '<div class="foot"><span class="url">%s</span><span>%s</span></div>' % (left, right)


def qr_img() -> str:
    b64 = base64.b64encode(QR_SVG.read_bytes()).decode()
    return '<div class="qr"><img src="data:image/svg+xml;base64,%s" alt=""></div>' % b64


SCORECARD_ROWS = [
    ("Calories", "2,320", "+320 over"),
    ("Protein", "88g", "−38 under"),
    ("Fiber", "13g", "−12 under"),
    ("Streak", "Broken", "was 6 days"),
]


def scorecard() -> str:
    rows = "".join(
        '<li><span class="sc-label">%s</span><span class="sc-value">%s</span>'
        '<span class="sc-delta">%s</span></li>' % r for r in SCORECARD_ROWS
    )
    return (
        '<div class="scorecard">'
        '<div class="scorecard-head"><span>Daily summary</span>'
        '<span class="scorecard-date">Thu, Jul 24</span></div>'
        '<ul class="scorecard-rows">%s</ul>'
        '<div class="scorecard-foot">0 of 4 goals met</div>'
        '</div>'
        '<p class="caption">Every other app. Every single day.</p>' % rows
    )


def thread() -> str:
    return (
        '<div class="thread">'
        '<div class="msg msg-you"><p>Why isn’t my weight moving?</p></div>'
        '<div class="msg msg-pulse">'
        '<div class="msg-who"><span class="pulse-dot"></span>Pulse</div>'
        # Illustrative, like the exchange already on the site — but it stays inside
        # what Pulse can actually see. No claims about how weight behaves in general;
        # everything here is a reading of this person's own log.
        '<p>Four days running at your protein floor — that part’s holding, and it’s the '
        'part that protects muscle. The scale hasn’t moved since Tuesday. Nothing in your '
        'log explains it, so give it through Sunday before you change anything.</p>'
        '</div></div>'
    )


# ── The slides ──────────────────────────────────────────────────────────────
# (filename, extra body classes, inner HTML). Order is post order, not posting
# order — the posting sequence lives in instagram-launch-posts.md.
SLIDES = [
    # Post 1 — the name change
    ("p1-s1-name", "", """
      {lockup}
      <div class="stage">
        <span class="was">NutriPulse</span>
        <h1>Footing.</h1>
        <p class="body wide">Same app. Same account.<br>Same coach.</p>
      </div>
      {foot}
    """),
    ("p1-s2-nothing-breaks", "", """
      {lockup}
      <div class="stage">
        <p class="eyebrow">If you already have it</p>
        <h1 class="md">Nothing<br>breaks.</h1>
        <p class="body wide">Your log, your goals, your streak — all still there.
          The icon just says something different.</p>
      </div>
      {foot}
    """),
    ("p1-s3-named-after-work", "", """
      {lockup}
      <div class="stage">
        <p class="eyebrow">The name</p>
        <h1 class="sm">Most apps here are named<br>after the medication.</h1>
        <p class="body wide">This one is named after <span class="grad">the work</span>.</p>
      </div>
      {foot}
    """),

    # Post 2 — why "Footing"
    ("p2-s1-quote", "", """
      {lockup}
      <div class="stage">
        <div class="rule"></div>
        <p class="quote">A footing is the base poured beneath a floor so
          <em>nothing above it sinks.</em></p>
      </div>
      {foot}
    """),

    # Post 3 — the beta
    ("p3-s1-beta-open", "", """
      {lockup}
      <div class="stage">
        <p class="eyebrow live"><span class="dot"></span>Now on TestFlight · iPhone</p>
        <h1 class="md">The beta<br>is open.</h1>
        <div class="qr-row">
          {qr}
          <p class="qr-note">Scan to join, or tap the link in bio.</p>
        </div>
      </div>
      {foot}
    """),
    ("p3-s2-free", "on-light", """
      {lockup_light}
      <div class="stage">
        <p class="eyebrow">While we build</p>
        <h1 class="md">Free while<br>we’re <span class="grad">building it</span>.</h1>
        <div class="meta-row">
          <span><span class="tick">✓</span> No card</span>
          <span><span class="tick">✓</span> No email list</span>
          <span><span class="tick">✓</span> One tap in</span>
        </div>
      </div>
      {foot}
    """),

    # Post 4 — coached, not scolded
    ("p4-s1-scorecard", "", """
      {lockup}
      <div class="stage">
        <p class="eyebrow">The problem</p>
        <h1 class="sm">Tracking shouldn’t feel<br>like getting graded.</h1>
        <div style="margin-top:52px">{scorecard}</div>
      </div>
      {foot}
    """),
    ("p4-s2-pulse", "", """
      {lockup}
      <div class="stage">
        <p class="eyebrow">The coach</p>
        <h1 class="sm">It already<br>read your day.</h1>
        <div style="margin-top:48px">{thread}</div>
      </div>
      {foot}
    """),
    ("p4-s3-coached", "", """
      {lockup}
      <div class="stage">
        <h1>Coached,<br>not <span class="grad">scolded</span>.</h1>
        <p class="body wide">Honest when you need it — never just to make you feel small.</p>
      </div>
      {foot}
    """),

    # Post 5 — founder note
    ("p5-s1-founder", "on-light", """
      {lockup_light}
      <div class="stage">
        <p class="eyebrow">Founder note</p>
        <h1 class="md">The unglamorous<br>half of the story.</h1>
        <p class="body wide">Why the app you downloaded has a different name this week.</p>
      </div>
      {foot}
    """),
]

PAGE = """<!doctype html>
<meta charset="utf-8">
<style>
{fonts}
</style>
<link rel="stylesheet" href="{css}">
<body>
<div class="slide {cls}">
{inner}
</div>
</body>
"""


def main() -> int:
    if not pathlib.Path(CHROME).exists():
        sys.exit("Google Chrome not found at %s" % CHROME)

    shutil.rmtree(BUILD, ignore_errors=True)
    BUILD.mkdir(parents=True)
    OUT.mkdir(exist_ok=True)

    fonts = font_css()
    css = (HERE / "slides.css").as_uri()
    parts = {
        "lockup": lockup(),
        # The mark is a gradient tile; it reads on cream unchanged.
        "lockup_light": lockup(),
        "foot": foot(),
        "qr": qr_img(),
        "scorecard": scorecard(),
        "thread": thread(),
    }

    for name, cls, inner in SLIDES:
        html = PAGE.format(fonts=fonts, css=css, cls=cls, inner=inner.format(**parts))
        src = BUILD / (name + ".html")
        src.write_text(html)

        png = OUT / (name + ".png")
        subprocess.run([
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=2",
            "--window-size=%d,%d" % (W, H),
            "--screenshot=%s" % png,
            "--virtual-time-budget=1500",
            src.as_uri(),
        ], check=True, capture_output=True)

        # Chrome wrote it at 2x; sips brings it to Instagram's native 1080 wide.
        subprocess.run(["sips", "-z", str(H), str(W), str(png)],
                       check=True, capture_output=True)
        print("  %s" % png.relative_to(HERE.parent.parent))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
