# Social image renderer

Slide images for @tryfooting, rendered from the same tokens as the marketing site.

```bash
python3 marketing/social/build.py
```

Writes `out/*.png` at **1080×1350** (Instagram 4:5 portrait). Needs nothing installed —
headless Chrome and `sips` ship with the machine, and the fonts come from
`marketing/site-v2/node_modules`, so run `npm install` there once if it's a fresh clone.

## Why this and not a design tool

Every slide carries the site's palette, type scale, and components. In a design file those
values are copies, and copies drift the first time the palette moves. Here `slides.css`
restates the tokens from `site-v2/src/styles.css` in one block at the top — change them
together and every slide re-renders in step.

The scorecard and the Pulse thread are rebuilt from the site's own markup rather than
screenshotted, so they stay legible at 1080px instead of being upscaled browser captures.

## Files

| | |
|---|---|
| `build.py` | Slide definitions and the render loop. Add a slide to `SLIDES`. |
| `slides.css` | Tokens, type scale, and components. Mirrors `site-v2/src/styles.css`. |
| `build/` | Generated HTML, one file per slide. Disposable — open one in a browser to debug a layout. |
| `out/` | The PNGs you upload. |

## Rendering notes

- Chrome renders at `--force-device-scale-factor=2` and `sips` downsamples to 1080 wide, so
  type is supersampled rather than hinted at final size. Rendering straight at 1x is visibly
  coarser on the serif.
- Fonts are base64-inlined into each HTML file. Chrome blocks `file://` font fetches under
  CORS, and pulling from a CDN would make the render depend on a network.
- The QR is `site-v2/public/testflight-qr.svg` — the same asset the site serves, so it can't
  drift from `links.ts`. After changing that link, re-render and re-verify the QR decodes:

  ```bash
  swift marketing/social/verify-qr.swift marketing/social/out/p3-s1-beta-open.png
  ```

## Copy

The captions, hashtags, and posting order live in `../instagram-launch-posts.md`. Voice rules
are in `../site-v2-voice.md` and they apply here — sentence case, no exclamation marks, and
the non-shaming law outranks anything that would convert better.
