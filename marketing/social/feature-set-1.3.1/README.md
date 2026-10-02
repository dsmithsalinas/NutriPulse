# Feature set — Footing 1.3.1

Ten social creatives (7 feed posts, 2 stories, 1 link ad) and an 8-slide carousel, "A day with Pulse", in the same design language as the
1.3.1 launch video (`../../launch-video-1.3.1`). Captions, alt text, hashtags and posting notes
are in `captions.md`.

| | |
|---|---|
| `posts.html` | Every post, as HTML. `posts.html?p=<id>` shows one. Shared pieces: the iPhone frame, Pulse's bubble, pills, the brand lockup. |
| `img/` | Light-mode screens from the 1.3.1 build and UI pieces cut from them. `shot-day.jpg` shows "GLP-1 · 5 mg" in place of the sample account's brand-name medication. |
| `fonts/` | Bricolage Grotesque and Figtree, from the app bundle. |
| `render.js` | Renders every post to `out/<id>.png` at 2× and downsamples with `sips`, like `../build.py`. A carousel (`slides` set) is one wide panorama, shifted under a 1080-wide window to cut `out/<id>-1.png` … `-8.png`. |
| `out/` | The images to upload. |

## Render

Needs Node and Playwright with its Chromium. `render.js` looks for Playwright at the path in
`$PLAYWRIGHT`, falling back to the install in `~/Documents/GitHub/admyt/node_modules/playwright`.

```bash
cd marketing/social/feature-set-1.3.1
node render.js                 # all ten
node render.js p03-floor-cleared  # one
```

The iPhone is drawn in CSS (`iphone()` in `posts.html`): a natural-titanium frame, black bezel,
the display at the screenshot's own 1206×2622 aspect, the Dynamic Island, side buttons and a
light glare, so any screen in `img/` can go on it.
