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

- **Built (Sep 29, `daylight/pulse-structured`, not deployed):** `coach-chat` asks for structured outputs. Chat returns `{reply, foods?, followUps?}` and the weekly recap `{reply, recap?, followUps?}`; `reply` always carries the full text, so older app versions are unaffected. Schemas and the clamping parser live in `_shared/pulse-context.ts`. The app renders the charts itself from its own data; Pulse only writes the words.
- **Built:** the Strong Week outlook runs on Sonnet 5.5 with the same fields in a JSON schema instead of the forced tool call (see `docs/your-strong-week.md`).
- **To ship, in order:** apply `20260929200000_coach_message_payload.sql` (nullable `coach_messages.payload`) and `20260929210000_pulse_profiles.sql`, deploy `coach-chat`, then redeploy `pulse-eval` (the provider and prompts changed). The app saves cards in `payload` and retries without it if the column is missing, and `coach-chat` treats a missing `pulse_profiles` row or table as "Pulse on", so the order is forgiving.

## What Pulse knows, Pulse off, and AI consent (step 8)

- **What Pulse knows** (Profile › Pulse › What Pulse knows, also from the Pulse start screen and an optional onboarding step): allergies and intolerances, how you eat (vegetarian, halal, dairy-free…), foods you love and would rather skip, and the existing kitchen situation. Stored in `pulse_profiles` (owner-only). Allergies and eating patterns are hard limits in the prompt, and `coach-chat` also drops any food card that names an allergy or avoided food.
- **Pulse learns in chat, with permission.** The reply's `remember` field carries what the user just said ("I can't stand salmon"); the app offers "Save to what Pulse knows?" and saves only on a tap. Allergies are never saved without that tap.
- **Three levels of off:** coaching notifications (existing toggle), Pulse on Today (hides the Pulse strip and hand-offs), and Pulse off (hides the tab, stops every AI call including the written Strong Week outlook). The setting is on the account, and `coach-chat` refuses with 403 `pulse_off` when it's off.
- **AI consent.** Before Pulse first uses someone's data, a sheet explains what goes to the AI provider and asks. "Not now" turns Pulse off. Apple's guideline 5.1.2 now asks for exactly this disclosure and permission; check the current wording before submission. Talk to Log's food parsing also uses AI and is disclosed in the same sheet, but has its own path.
- **Decided (Sep 29):** Your Strong Week is the only thing that goes out on Mondays (the 8 AM reminder and the Today card). Pulse never sends a weekly summary on its own; it shows a **Monday Recap** pill on the start screen, and the recap is generated only when the user taps it.

## Code changes the Pulse start screen needs

- `CoachViewModel`: remove the automatic `maybeGenerateCheckin` / `maybeGenerateWeeklySummary` calls on load and on tab activation (`generateDueAutoMessages`, `refreshAutoMessages`). Keep `WeeklyRecapSchedule` to decide when the Monday Recap pill appears; tapping it sends a `weekly_summary` request.
- Build the start-screen suggestions on the device, extending `CoachSuggestionBuilder` (today's protein gap, shot-cycle day, time of day, Monday–Wednesday recap). No model call until the user sends something.
- The server-side "recent Pulse messages" handling stays: it still keeps replies from repeating earlier ones.

## Deferred testing (folded into the rebuild)

Not done as a separate pass before the redesign: the rebuild work is compiled and tested as it lands, and these checks ride along with it.

- ~~Build and run all iOS tests.~~ Done Sep 29: the merged Strong Week + Pulse code compiles and every test passes.
- Deploy `coach-chat` from `main` and generate a Strong Week outlook on a device.
- Confirm the Monday 8 AM reminder is pending and arrives (the scheduler was serialized in the merge).
- Redeploy `pulse-eval` before using the evaluator again (the prompt hash changed).

## Build status (Sep 29)

Each step is its own branch, stacked in order; each was built, tested and checked in the simulator before the next.

| Step | Branch | What landed |
|---|---|---|
| Foundation | `daylight/foundation` | Daylight tokens in `Theme`, bundled Bricolage Grotesque (96pt cut) and Figtree, `DaylightComponents` (tile, eyebrow, pop-in, meter bar, counting number, flow layout), floating tab bar |
| Pulse start screen | `daylight/pulse-start` | No automatic check-in or weekly summary; start screen with on-device tiles and Monday Recap; New topic |
| Today and Log sheet | `daylight/today-log` | Tile grid with liquid protein fill, water picker with Undo (synced tombstones), movement sheet; Log sheet with Talk / Search / Scan / Favorites and the header meal everywhere |
| Secondary screens | `daylight/pulse-structured` | Every screen reached from the main tabs (Analytics, summaries, goal builder, experiments, notification and dose settings, Today's lower cards and sheets, Strong Week, Body, onboarding, sign-in), built on shared chrome in `DesignSystem/DaylightChrome.swift`: pushed pages use `DaylightPageTitle` + `.daylightSubpage`, sheets use `SheetHeader`, settings forms use `.daylightForm()` |
| Remaining screens | `daylight/screens` | Progress (floor-days hero, trend vs the previous period, stat tiles), Goals (hero goal, experiment tile), Shot day (hold to log, with an immediate VoiceOver path), Profile (targets hero, grouped setting tiles) |

Debug launch flags for checking screens without an account (`--tour` turns on all of them, with the tab bar, to click through the whole app): `--pulse-preview`, `--water-preview`, `--log-preview`, `--shot-preview`, `--profile-preview`, `--onboarding-preview`, `--widget-preview`, `--store-today`, `--store-food`, `--progress-preview`, `--goals-preview`.

### Known gaps

- **Past conversations are one stream.** Pulse history has no conversation id, so the history button shows the whole transcript. Separate conversations need a `conversation_id` on `coach_messages`.
- **Recents show "N servings", not "½ cup".** Local food logs don't store a serving description.
- **"My foods" in Search means favorites.** FatSecret results carry no ownership flag.
- **No Edit on the Favorites grid** yet.
- **Shot day has no titration week** ("week 6"); nothing records it.
- The mockups are light-only; dark-mode colors are our own picks in the same slate family.
- Everything that needs a signed-in account (real search, favorites, water sync, recap) still needs a pass on a device before TestFlight.

## Analytics, experiments and Goals (Sep 29)

- **Analytics is questions**, one scrolling row of chips: shot days (first when there's GLP-1 history), where protein comes from (top 5 foods), whether the weight trend is real (smoothed trend, shot days and dose changes marked, "too few weigh-ins" under 4), protein and calories, movement, body composition. Each answers with one takeaway computed from data and an "Ask Pulse about this". Logic in `Core/Coaching/AnalyticsQuestions.swift`.
- **Experiments** show what they measure, run Setup → Running (day X of Y, today's check-in) → Result. The result compares the outcome on days you did it vs days you didn't, and says "Not enough data to tell yet" under 5 days a side or when the gap is under half the pooled SD. Never causal. Starters come only from real patterns in your data. A running experiment adds an "Experiment · day X of Y" tile to the Pulse start screen that opens it. Logic in `Core/Coaching/ExperimentInsights.swift`.
- **Goals**: a built-in protein-floor goal (never empty), a gentle note past 3 active goals, one-time lime wins for completion and the highest 7/14/30-day streak reached, and a trophy shelf with non-shaming wording.
- **Honesty rule**: text worked out by fixed rules on the device is never labelled as Pulse.
- Known: a streak milestone that was celebrated once won't celebrate again in a later streak; the floor card's "Change your floor in Profile" is text, not a link.

## Units and the widget (Sep 30)

- **Units:** storage stays kg and cm; every screen converts through `UnitSystem`, and imperial reads "lbs" and inches everywhere (weight goals included). Pulse receives `user.units` and weights already in the user's units, and a UNITS prompt rule converts kg-named fields (body goals) before it speaks. Verified live: an 80 kg target comes back as 176.0 lbs.
- **Widget:** the Protein Floor widget uses the Daylight theme and fonts (Theme.swift and the fonts are compiled into the extension; PulseMark moved to `Shared/`). Its views live in `Shared/ProteinFloorWidgetViews.swift` so the app can show them under `--widget-preview`.

## Process rule

Commit and push before any deploy or TestFlight upload, whichever tool does it. Builds 183/184 shipped from uncommitted code, which is how the Strong Week work nearly got lost.
