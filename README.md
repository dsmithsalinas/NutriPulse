# Footing — marketing

## `index.html`
A self-contained marketing landing page mockup for Footing. Positioning:
**"Coached, not scolded."** — the anti-scorecard nutrition coach, with GLP-1 as
the acquisition beachhead. Copy and strategy come from the pre-TestFlight brainstorm
(see `../ENHANCEMENTS.md` for the product spine it's built on).

- Single file, no build step, no external requests. Open it directly in a browser.
- The animated logo (`../orbit-exports/NutriPulse Logo Animation.mp4`) and its poster
  are **embedded as base64 data URIs**, so the file is fully portable (~376 KB).
  **Still stale since the rename.** The splash uses the *light* variant (the splash
  background is `#F3F3F9`), and only the dark variant has been re-rendered for Footing
  so far — see `Footing Logo AnimationDark.mp4`, which the site does not use. Once the
  light variant lands, re-embed it and regenerate the poster from its final frame
  (760×427 JPEG, matching the current one).
- Behavior: logo splash intro → docks to top → hero → gated section-by-section reveal
  triggered by "See how it works" / "For GLP-1" / nav links. Respects reduced-motion.
- Bespoke CSS, system font stack, brand palette (indigo `#6366F1` → violet `#8B5CF6`,
  ink `#14163A`). Not a framework.

## App Store listing
Set in App Store Connect, not in this repo — recorded here so the two don't drift.

| Field | Value | Limit |
|---|---|---|
| Name | `Footing` | 30 |
| Subtitle | `Protein-first GLP-1 coaching` | 30 (uses 28) |

The subtitle carries the GLP-1 search term now that the name doesn't. Keywords
(100 chars, invisible to users) should still cover: GLP-1, semaglutide, tirzepatide,
Zepbound, Wegovy, protein, macros. If branded search grows enough to spare the
keyword, `Coached, not scolded` is the intended swap.

### Status
Mockup / design exploration — **not yet a live web app** (Footing is iOS-only for
now). If this becomes a real site, next steps: wire the "Join the beta" CTA to real
email capture (a Supabase table works) and split the inline CSS/JS into assets.
