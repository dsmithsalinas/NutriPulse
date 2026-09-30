# Daylight redesign — handoff

Mockups (claude.ai canvas, private to the owner): https://claude.ai/artifact/NC4UbuG51bJD52GU19ZkDN
Open it from claude.ai, or with `/artifacts` in Claude Code. The **C — Daylight** row is the chosen direction; rows A (Bedrock) and B (Signal) were rejected. Artboards that work in Play mode are marked on the canvas.

## Look

- Bright, tiled layout on a cool neutral background (`#EEF1F6`), white tiles with 20–28 px radii, deep indigo hero tile (`#1E1B4B` / `#4F46E5`), lime accent (`#D9F99D`) for wins and the Log button, sky (`#E0F2FE`) for water.
- Type: Bricolage Grotesque (display, numbers) and Figtree (body). Numbers use tabular figures.
- Motion: tiles spring in with a slight overshoot, the protein tile fills like liquid with a moving wave, bars and lines draw in, and the protein number counts up. Everything switches off when Reduce Motion is on.
- **Pulse's logo is the existing Pulse mark** (`PulseMark` in `Features/Today/Components/UnderEatingNudgeCard.swift`): a faint full ring, a 250° arc clockwise from 12 o'clock with round caps, and a dot where the arc ends. Use it everywhere Pulse appears (tab bar, chat header, avatars, Today's Pulse strip), never a heartbeat line. Early mockups used a heartbeat line; they have been updated.
- Floating dark tab bar: Today · Progress · Log (+) · Pulse · Profile; the selected tab expands into a labelled white pill.

## Screens and decisions

- **Today:** protein tile (liquid fill), a calories tile that also lists carbs, fat, and fiber with their own bars, a shot-cycle tile, water, movement, and meals. The water tile's + adds your usual amount in one tap; tapping the rest of the tile opens a size picker (250/500/750 ml or 8/12/16 oz, custom, Undo).
- **Log sheet:** tabs are Talk / Search / Scan / **Favorites** (replaces Manual). The meal is pre-filled from the time of day and shown in the header ("Adding to Dinner ▾"). **+** logs straight to that meal; tapping a food's name opens the confirm step (serving and meal). Recents' "log again" also uses the header meal.
  - Talk: idle state with a large mic button plus a text box for typing; a listening state with the live transcript, parsed items, and a "This clears your floor" tile. A keyboard button switches from talking to typing.
  - Search: filter chips (All, Protein-dense, My foods), favorites first, "Can't find it? Enter it yourself" at the bottom (manual entry moves here).
  - Favorites: favorites grid on top, then **Recents from the last 72 hours** grouped by day, with a + to log again and a star to add to favorites. Recents hide foods already in favorites.
- **Pulse opens to a start screen and never messages first.** Opening the tab no longer generates a check-in or weekly summary. It shows the start screen (artboard *Daylight · Pulse (start screen — opens here)*):
  - a greeting ("What's on your mind, Dustin?") and one line on what Pulse can see
  - **Suggested for right now:** two or three tiles built on the device from today's data, with no AI call: the protein gap, the shot-cycle day, and a **Monday Recap** pill on Monday–Wednesday. Tapping one sends it as the first message.
  - **Or talk about:** fixed topic chips (Meal ideas, How I'm trending, Eating out, Workouts & recovery)
  - **Pick up where you left off:** the last conversation, if there is one; a history button opens past conversations
  - an open text box with a mic button
  The weekly summary is only generated when the user taps the Monday Recap pill. The *Pulse starts the chat* artboard is superseded; proactive coaching stays in notifications (smart coaching, Your strong week).
- **Pulse conversation:** chat bubbles with one-tap food cards (from frequently logged foods), in-chat shot-cycle check-in, the weekly summary as a structured card (story, went well, pattern, focus, a 7-day bar chart), follow-up chips, a "New topic" button back to the start screen, and a text box with a mic button.
- **Progress, Goals & experiments, Shot day (hold to log), Profile:** see the canvas.

## Things the redesign needs from the backend

- Structured Pulse replies (one-tap cards, the recap card) need `coach-chat` to return labelled fields alongside the text, via structured outputs. The app renders the charts itself from its own data; Pulse only writes the words.
- The Strong Week outlook still uses a forced tool call on `claude-sonnet-4-6`. Moving it to Sonnet 5.5 means switching it to structured outputs (see `docs/your-strong-week.md`).
- **Decided (Sep 29):** Your Strong Week is the only thing that goes out on Mondays (the 8 AM reminder and the Today card). Pulse never sends a weekly summary on its own; it shows a **Monday Recap** pill on the start screen, and the recap is generated only when the user taps it.

## Code changes the Pulse start screen needs

- `CoachViewModel`: remove the automatic `maybeGenerateCheckin` / `maybeGenerateWeeklySummary` calls on load and on tab activation (`generateDueAutoMessages`, `refreshAutoMessages`). Keep `WeeklyRecapSchedule` to decide when the Monday Recap pill appears; tapping it sends a `weekly_summary` request.
- Build the start-screen suggestions on the device, extending `CoachSuggestionBuilder` (today's protein gap, shot-cycle day, time of day, Monday–Wednesday recap). No model call until the user sends something.
- The server-side "recent Pulse messages" handling stays: it still keeps replies from repeating earlier ones.

## Deferred testing (folded into the rebuild)

Not done as a separate pass before the redesign: the rebuild work is compiled and tested as it lands, and these checks ride along with it.

- Build and run all iOS tests (`xcodegen`, then ⌘U). The merged Strong Week + Pulse code has not been compiled yet.
- Deploy `coach-chat` from `main` and generate a Strong Week outlook on a device.
- Confirm the Monday 8 AM reminder is pending and arrives (the scheduler was serialized in the merge).
- Redeploy `pulse-eval` before using the evaluator again (the prompt hash changed).

## Process rule

Commit and push before any deploy or TestFlight upload, whichever tool does it. Builds 183/184 shipped from uncommitted code, which is how the Strong Week work nearly got lost.
