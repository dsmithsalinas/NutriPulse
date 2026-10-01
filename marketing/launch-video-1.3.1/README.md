# Footing 1.3.1 launch video

`Footing-1.3.1.mp4` — 61 s, 1920×1080, 60 fps, H.264, light mode, narrated by Pulse.
The MP4 is not tracked in git (it's over GitHub's 100 MB file limit); the source below is.

## Source
- `source/site/index.html` — the whole piece as a timeline of Web Animations. `seek(t)` freezes
  the frame at any time, so rendering is frame-exact. Scenes are marked `S0`–`S10` with their times.
- `source/site/img/` — light-mode screenshots from the 1.3.1 build, plus the UI pieces cut from them
  (`crops.json` records where each came from).
- `source/site/fonts/` — Bricolage Grotesque and Figtree, copied from the app bundle.

## Re-render
Needs Node and Playwright with its Chromium (the script currently points at the Playwright install in
`~/Documents/GitHub/admyt/node_modules`; change the `require` path at the top of `render.js` if that moves).

```bash
cd marketing/launch-video-1.3.1/source
node render.js stills 11.8 16.9      # spot-check frames → stills/
node render.js frames 60             # all 3,660 frames → frames/ (about 4 minutes)
swiftc -O encode.swift -o encode
./encode frames ../Footing-1.3.1.mp4 60
rm -rf frames
```
