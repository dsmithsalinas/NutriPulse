# NutriPulse — Pre-TestFlight Enhancements (Build Spec)

Outcome of a product brainstorm. This is the plan for the next build phase before
handing NutriPulse to beta testers. Read alongside `PLAN.md` (original architecture).

## The spine
NutriPulse is **one product idea expressed through Pulse**: a coach who's paying
attention. Three acts:
1. **Effortless in** — you talk, Pulse logs. Kill the mundane search-tap-tap friction.
2. **Honest but actionable** — never show a gap without a path. "You're 40g short on
   protein" is a scorecard; "you're 40g short — Greek yogurt + the chicken you like
   closes it, and it's a GLP-1 day so let's keep it dense" is a coach.
3. **Earned celebration** — the carrot every other tracker forgets. Praise only has
   currency *because* Pulse is also honest. Same voice, both directions.

Guiding principle: **honesty is what makes the celebration mean something.** No
trophy case, no points, no badges — that cruft would cheapen the honest-coach brand.

## What the TestFlight beta must prove
1. Is logging fast enough to *sustain* the habit? (retention of the core loop)
2. Is Pulse valuable enough to justify its per-use cost? (value vs unit economics)
3. Does NutriPulse deliver value users aren't getting elsewhere? (differentiation —
   the wedge is **GLP-1–native** coaching: protein floors not calorie ceilings, a
   coach that understands the injection/appetite cycle)

## Build sequence
- **Phase 0 — Brand foundation (do first, small).** Expand `Theme.swift` from a
  placeholder into a real design system. Everything downstream inherits it; skipping
  it means rebuilding new UI during a later brand pass.
- **Phase 1 — Features on the foundation.** Talk-to-log, celebration, instrumentation.
  Celebration is *co-designed* with the brand, not retrofitted.
- **Phase 2 — Screen polish, last.** Visual refinement of existing stable screens
  (Today, Analytics, Profile) once functionality won't churn.

---

## Phase 0 — Brand foundation
Today `Theme.swift` has only generic system colors, spacing, ring dims. Add:
- **Brand palette** from the app icon gradient: indigo `#6366F1` → violet `#8B5CF6`.
  Define primary, primary-gradient, accent, plus semantic surface/background/text tokens.
- **Typography scale** (display / title / body / caption) — one place, used everywhere.
- **Refined nutrient ring colors** tuned to the brand, replacing raw `Color.orange` etc.
- **Core component styles** the new features will use: primary button, card, and the
  ring (already partially there).
- Wire the app icon from `orbit-exports` into the asset catalog if not already.

---

## Phase 1A — Talk-to-log (natural-language food logging)
**Goal:** "I had a Chipotle bowl with chicken, rice, pico, lettuce, cheese" → a
correct, confirmable food log, in one sentence.

**Architecture — two-hop, FatSecret-grounded (accuracy is the priority):**
1. **Claude decomposes** the sentence into named, quantified items using its knowledge
   of what's actually in the dish (e.g. Chipotle → chicken, cilantro-lime white rice,
   pico, romaine, Monterey Jack blend). Claude is the *parser/entity extractor*.
2. **FatSecret provides the numbers** — look up each named item; FatSecret carries
   branded entries for big chains.
3. **Claude resolves the match** — hand FatSecret's top candidates per item back to
   Claude to pick the right one given context. This is what stops "cheese" matching
   random cheddar. Demo vs trustworthy hinges on this step.
4. **Confirm card** — user reviews parsed items + macros, edits any row, one-tap confirm.
   Never blind-insert AI/looked-up values into the log.

- **Model: Claude Haiku** (`claude-haiku-4-5`) — this is structured extraction, not
  reasoning. Keeps cost-per-use low.
- **Build via Claude tool-use** — one agentic call where Claude can invoke a
  FatSecret-search tool as many times as needed. Check the `claude-api` reference for
  tool-use specifics. New Edge Function (e.g. `parse-food`), same proxy pattern as
  `coach-chat`. Never call Claude or FatSecret directly from the app.
- **Confirm-card UX is make-or-break** — a 5-component bowl = 5 rows. Must make
  "all correct → one tap" effortless while letting you fix a single row.

**Scope cuts (park for v2):**
- **No photo/vision logging.** Pricier, less accurate, bigger UI lift; text-to-log
  tests the actual itch. Great v2 headline feature.

**Coverage reality:** FatSecret nails big chains (Chipotle, Starbucks, McDonald's).
Local restaurants won't be in it — Claude falls back to generic components
("grilled chicken, white rice"), still fine, just approximate.

**Riskiest assumption (test as primary user, before TestFlight):** that the
decompose→lookup→resolve chain returns correct matches *without* heavy confirm-card
editing, and is *fast enough* (multiple network hops) to still feel effortless.
Self-test: log real meals by voice for 3 days. If the confirm card is mostly "yep" →
you have a product. If it's "wrong again" or slow → tune matching/latency before beta.

## Phase 1B — Earned celebration
- **Detect wins in Swift, not Claude.** "All rings closed," "protein floor hit N days
  running," "first fiber goal ever" = a small client-side rules layer reading the daily
  summary. Don't pay an API call to *notice* a win.
- **Free celebration = the ring moment.** When the last ring closes, a real animated
  beat (not a static fill). Fires every time, costs nothing.
- **Verbal celebration only when the user is already talking to Pulse.** Claude speaks
  praise only inside a conversation the user already initiated — no extra calls.
- **Reward logging early, outcomes later.** Week one: celebrate that you showed up and
  logged (habit is the win). Once sticky: celebrate hitting the actual goals. Track
  which streak type applies based on tenure/consistency.
- **No trophy case** — no points/badges/leaderboards. Celebration lives in Pulse's
  voice + the rings only.

## Phase 1C — Instrumentation & feedback (so the beta produces signal)
Without this, even *you* can't tell if talk-to-log beat searching. Capture:

**Goal 1 (logging sustainable):** time-to-log (intent → confirmed), logs/day,
share of logs via talk-to-log vs search vs favorite, **confirm-card edit rate**
(how often a row gets corrected — the trust proxy), day-1/3/7 return, days-logged/week.

**Goal 2 (Pulse value vs cost):** Pulse messages/user/week, check-in read rate,
token cost per active user, share of sessions with a Pulse interaction.

**Goal 3 (differentiation):** mostly qualitative (feedback + interviews). Proxy:
retention overall, and whether GLP-1 users retain better than non-GLP-1 users.

**Tooling — DECIDED: TelemetryDeck.** Privacy-first, iOS-native, simple, cheap,
clean for TestFlight (no consent headaches). Integrate the Swift SDK, define signals
for the metrics above (time-to-log, log source, confirm-card edit rate, Pulse usage,
day-N return). Keep signal names in one enum so they're consistent and greppable.

**In-app feedback:** a lightweight "Send feedback" (Profile → Send Feedback, or
shake-to-report) that posts to Supabase. Cheap, and it's how you'll hear *why* a
tester churned — the qualitative half of Goal 3.

**Crash reporting:** TestFlight + Xcode Organizer give you crashes automatically once
you cut a build — no extra SDK needed for beta.

---

## Distribution note
TestFlight is **not** required for solo use. With the paid Apple Developer account, an
Xcode-installed build runs on your iPhone for up to a year. Keep using the direct-Xcode
build as your daily driver during development (instant builds, live debugger). Cut a
TestFlight build only when handing to other testers. TestFlight builds expire every 90 days.

## Non-goals / parked
- Photo/vision food logging (v2 headline)
- Trophy case / gamification (rejected — off-brand)
- FatSecret grounding is IN (not deferred) — accuracy was chosen over speed
