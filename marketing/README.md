# Footing — marketing

> **The live site is `site-v2/`, hosted on Cloudflare Workers at
> [tryfooting.app](https://tryfooting.app).** See
> [`site-v2/DEPLOY.md`](site-v2/DEPLOY.md) for hosting, the domain, and the cutover order.
>
> | Path | What it is |
> |---|---|
> | `site-v2/` | The current site — Vite + React + R3F. Deployed to Cloudflare. |
> | `redirect/` | Stubs published to the old GitHub Pages URL, forwarding to the new domain. **Load-bearing** — `Config.swift:37` points shipped app builds at the old privacy URL. |
> | `index.html`, `privacy.html` | The v1 single-file site. **No longer deployed**, kept for reference. Its content now lives in `site-v2/`. |
> | `site-v2-blueprint.md` (in `../`) | Creative direction, page architecture, and the direction-change addendum. |
> | `site-v2-voice.md`, `site-v2-webgl.md` (in `../`) | Copy voice guide and the 3D spec. |
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
