# Daylight redesign — handoff

Mockups (claude.ai canvas, private to the owner): https://claude.ai/artifact/NC4UbuG51bJD52GU19ZkDN
Open it from claude.ai, or with `/artifacts` in Claude Code. The **C — Daylight** row is the chosen direction; rows A (Bedrock) and B (Signal) were rejected. Artboards that work in Play mode are marked on the canvas.

## Look

- Bright, tiled layout on a cool neutral background (`#EEF1F6`), white tiles with 20–28 px radii, deep indigo hero tile (`#1E1B4B` / `#4F46E5`), lime accent (`#D9F99D`) for wins and the Log button, sky (`#E0F2FE`) for water.
- Type: Bricolage Grotesque (display, numbers) and Figtree (body). Numbers use tabular figures.
- Motion: tiles spring in with a slight overshoot, the protein tile fills like liquid with a moving wave, bars and lines draw in, and the protein number counts up. Everything switches off when Reduce Motion is on.
- Floating dark tab bar: Today · Progress · Log (+) · Pulse · Profile; the selected tab expands into a labelled white pill.

## Screens and decisions

- **Today:** protein tile (liquid fill), a calories tile that also lists carbs, fat, and fiber with their own bars, a shot-cycle tile, water, movement, and meals. The water tile's + adds your usual amount in one tap; tapping the rest of the tile opens a size picker (250/500/750 ml or 8/12/16 oz, custom, Undo).
- **Log sheet:** tabs are Talk / Search / Scan / **Favorites** (replaces Manual). The meal is pre-filled from the time of day and shown in the header ("Adding to Dinner ▾"). **+** logs straight to that meal; tapping a food's name opens the confirm step (serving and meal). Recents' "log again" also uses the header meal.
  - Talk: idle state with a large mic button plus a text box for typing; a listening state with the live transcript, parsed items, and a "This clears your floor" tile. A keyboard button switches from talking to typing.
  - Search: filter chips (All, Protein-dense, My foods), favorites first, "Can't find it? Enter it yourself" at the bottom (manual entry moves here).
  - Favorites: favorites grid on top, then **Recents from the last 72 hours** grouped by day, with a + to log again and a star to add to favorites. Recents hide foods already in favorites.
- **Pulse:** chat bubbles with one-tap food cards (from frequently logged foods), in-chat shot-cycle check-in, the weekly summary as a structured card (story, went well, pattern, focus, a 7-day bar chart), suggestion chips, and a text box with a mic button.
- **Progress, Goals & experiments, Shot day (hold to log), Profile:** see the canvas.

## Things the redesign needs from the backend

- Structured Pulse replies (one-tap cards, the recap card) need `coach-chat` to return labelled fields alongside the text, via structured outputs. The app renders the charts itself from its own data; Pulse only writes the words.
- The Strong Week outlook still uses a forced tool call on `claude-sonnet-4-6`. Moving it to Sonnet 5.5 means switching it to structured outputs (see `docs/your-strong-week.md`).
- Pulse's weekly summary (in Pulse) and Your Strong Week (on Today) overlap on Mondays. Decide whether the redesign keeps both or folds the summary into Strong Week.

## Deferred testing (do with the first redesign build)

- Build and run all iOS tests (`xcodegen`, then ⌘U). The merged Strong Week + Pulse code has not been compiled yet.
- Deploy `coach-chat` from `main` and generate a Strong Week outlook on a device.
- Confirm the Monday 8 AM reminder is pending and arrives (the scheduler was serialized in the merge).
- Redeploy `pulse-eval` before using the evaluator again (the prompt hash changed).

## Process rule

Commit and push before any deploy or TestFlight upload, whichever tool does it. Builds 183/184 shipped from uncommitted code, which is how the Strong Week work nearly got lost.
