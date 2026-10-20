# Footing — marketing

## Current approved Footing logos

The **living-dot wordmark (option 02)** and **lime-window Cove app icon (option 06)** are the current approved Footing product logos. Use these assets for all new marketing and product branding:

- [Wordmark — SVG](brand/current/footing-wordmark.svg) · [transparent PNG](brand/current/footing-wordmark.png)
- [Reversed wordmark for dark backgrounds — SVG](brand/current/footing-wordmark-reversed.svg) · [transparent PNG](brand/current/footing-wordmark-reversed.png)
- [App icon — 1024px PNG](brand/current/footing-app-icon.png) · [editable SVG](brand/current/footing-app-icon.svg)
- [Approved asset usage and specifications](brand/current/README.md)

The wordmark uses **Inter Semibold 600**, with Cove replacing the dot of the i. These assets supersede the older Footing ring logo lockups in `orbit-exports/` and historical marketing examples below. Pulse retains its separate faceless ring as the coach identity.

The website uses the approved copies in `site-v2/public/brand/`. Its header/footer, browser icons and social preview use this branding. The app icon and sign-in wordmark are prepared locally for the next app release; TestFlight distribution is handled separately.

> **The live site is `site-v2/`, hosted on Cloudflare Workers at
> [tryfooting.app](https://tryfooting.app).** See
> [`site-v2/DEPLOY.md`](site-v2/DEPLOY.md) for hosting, the domain, and the cutover order.
>
> | Path | What it is |
> |---|---|
> | `site-v2/` | The current site — Vite + React, in the app's Daylight design (Sep 30, 2026). No 3D; the hero is the app's animated protein tile. Legal pages are static HTML in `site-v2/public/`. Deployed to Cloudflare. |
> | `redirect/` | Stubs published to the old GitHub Pages URL, forwarding to the new domain. **Load-bearing** — `Config.swift:37` points shipped app builds at the old privacy URL. |
> | `index.html`, `privacy.html` | The v1 single-file site. **No longer deployed**, kept for reference. Its content now lives in `site-v2/`. |
> | `site-v2-blueprint.md` (in `../`) | Creative direction, page architecture, and the direction-change addendum. |
> | `site-v2-voice.md` (in `../`) | Copy voice guide, still current. `site-v2-webgl.md` is the retired 3D spec, kept for history. |
>
> Everything below documents the **v1** site and is retained as history.

---

## `index.html`
A self-contained marketing landing page mockup for Footing. Positioning:
**"Coached, not scolded."** — the anti-scorecard nutrition coach, with GLP-1 as
the acquisition beachhead. Copy and strategy come from the pre-TestFlight brainstorm
(see `../ENHANCEMENTS.md` for the product spine it's built on).

- Single file, no build step, no external requests. Open it directly in a browser.
- The animated logo (`../orbit-exports/Footing Logo Animation.mp4`) and its poster
  are **embedded as base64 data URIs**, so the file is fully portable (~354 KB).
  The poster is the animation's final frame — the resolved lockup — exported at
  760×427 JPEG so there's no flash of empty space before playback starts.
  To swap the animation later: re-encode, re-run base64 on the mp4 and on a fresh
  final-frame export, and replace both data URIs in the `#splash` block.
- The splash background uses `var(--ground)` to match the animation's own canvas
  (`#F6F5FD`). If a future re-render changes that canvas colour, update the token
  to match or the rounded video card will show its edge against the page.
- `Footing Logo AnimationDark.mp4` is the dark-background variant. The site is
  light-only and does not reference it; it's kept for other surfaces.
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
