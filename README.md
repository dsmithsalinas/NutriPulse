# NutriPulse — marketing

## `index.html`
A self-contained marketing landing page mockup for NutriPulse. Positioning:
**"Coached, not scolded."** — the anti-scorecard nutrition coach, with GLP-1 as
the acquisition beachhead. Copy and strategy come from the pre-TestFlight brainstorm
(see `../ENHANCEMENTS.md` for the product spine it's built on).

- Single file, no build step, no external requests. Open it directly in a browser.
- The animated logo (`../orbit-exports/NutriPulse Logo Animation.mp4`) and its poster
  are **embedded as base64 data URIs**, so the file is fully portable (~376 KB).
- Behavior: logo splash intro → docks to top → hero → gated section-by-section reveal
  triggered by "See how it works" / "For GLP-1" / nav links. Respects reduced-motion.
- Bespoke CSS, system font stack, brand palette (indigo `#6366F1` → violet `#8B5CF6`,
  ink `#14163A`). Not a framework.

### Status
Mockup / design exploration — **not yet a live web app** (NutriPulse is iOS-only for
now). If this becomes a real site, next steps: wire the "Join the beta" CTA to real
email capture (a Supabase table works) and split the inline CSS/JS into assets.
