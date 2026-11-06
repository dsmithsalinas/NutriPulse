# Restaurant context for food logging

Implementation plan and build record · November 6, 2026 · Footing iOS

Search and Talk will share an optional restaurant selection for the current logging session. Talk will distinguish restaurant names from ingredients before resolving food, and ask for a checklist review when a customizable meal is underspecified. The initial target is ambiguous language around Chipotle, while preserving successful descriptions such as Texas Roadhouse meals.

The owner selected automatic detection plus manual selection, one restaurant per entry, and a checklist instead of guessed bowl ingredients. The approved flow is implemented in the native app and additive hosted endpoints. The original concepts remain design references; native keyboard screenshots and validation are recorded below.

## Current behavior and failure points

| Source | Current behavior | Change |
| --- | --- | --- |
| `NutriPulse/Features/FoodLogging/FoodLoggingView.swift` | Owns separate Search and Talk view models and keeps them across tab changes. | Own the shared restaurant context and presentation here. |
| `NutriPulse/Core/Networking/TalkToLogClient.swift` | Sends only `{text}` and expects `{items}`. | Send a versioned request with restaurant context and checklist answers; decode clarification states. |
| `supabase/functions/parse-food/index.ts` | Prompt explicitly decomposes a Chipotle chicken bowl into assumed rice, salsa, lettuce, and cheese before lookup. | Separate intent extraction, clarification, composition confirmation, and food resolution. Never add unnamed ingredients as facts. |
| Same parser | Model selects candidates from eight search results; the resolver then takes the first serving returned by food.get.v4. | Validate candidate provenance and restaurant fit; resolve an explicit serving and show its portion in review. |
| `NutriPulse/Core/Networking/FatSecretClient.swift` and `supabase/functions/search-food/index.ts` | Send/search one plain query with pagination. | Add optional restaurant context, maintain scoped pagination, and label fallback matches. |
| `NutriPulse/Features/FoodLogging/FoodSearchViewModel.swift` | Search task is keyed on query; pagination checks cancellation. | Key requests on query plus context revision; reject late responses from previous restaurant selections. |
| `NutriPulse/Models/ParsedFoodItem.swift` and Talk confirmation rows | Track provider brand, source, external food ID and per-serving nutrition. | Add response-level restaurant context and row-level match/serving provenance for review. Keep the provider's brand accurate. |
| `NutriPulse/Core/AI/TalkCorrectionParser.swift` | Deterministic corrections change quantity or inclusion after parsing. | Preserve this simple correction path; ingredient or restaurant changes that need new lookup must return to guided resolution. |

The likely problem is a combination of ambiguous language and premature decomposition. A restaurant field improves intent, but does not establish menu coverage or guarantee that a candidate is the right item.

## Proposed experience

### Shared restaurant selection

Place a compact Restaurant control below the existing Talk/Search tabs. With no selection it reads “Restaurant (optional)”; with one selected, show “Restaurant: Chipotle” with change/remove controls. Keep it available when Search collapses its header during typing. Show it only on Search and Talk, without changing Scan or Favorites behavior.

The picker allows a known name or a custom/local restaurant name. Start with a small maintained alias list including Chipotle and Texas Roadhouse; this is intent normalization, not a menu directory. A custom name remains valid context even when the provider has no matching brand. Do not imply that suggestions establish restaurant menu availability. Recent restaurants can be deferred until after the core flow works.

Keep the selection when switching Search and Talk, changing the meal header, correcting the current draft, or retrying a failed request. Closing the logging sheet clears it. “Add something else” after a successful save starts a fresh entry and clears automatic restaurant context; offer an explicit “Keep restaurant” action if continuation is desired. No automatic carryover to a later meal or new sheet. Sign-out/account change always clears the context and drafts.

### Automatic recognition and ambiguity

Treat “from Chipotle,” “at Chipotle,” and equivalent explicit venue language as restaurant evidence. Treat “chipotle sauce,” “chipotle peppers,” and clear seasoning descriptions as food ingredients. Bare “chipotle chicken” remains ambiguous and gets a short choice: restaurant or seasoning. Avoid routing every mention of chipotle to the chain.

Manual selection establishes the venue. If the transcript explicitly names a different restaurant, ask which to use before lookup; never silently switch or apply the selected restaurant to a contradictory description. A detected restaurant appears in the same editable control. Removing an automatically detected restaurant records that rejection for this draft so the next parse cannot immediately re-add it. A “seasoning” choice is also an explicit interpretation, retained through retries and corrections.

Speech recognition errors and uncertain spellings may trigger a suggestion, not an automatic brand assignment. Selecting Chipotle before dictation provides context without requiring the recognizer to spell it correctly. Keep the transcript editable. Parser improvements cannot recover words missing from audio with certainty.

If one transcript names multiple restaurants, ask the person to split it into separate entries in the first version. Do not assign one restaurant to everything. A packaged beverage's manufacturer may differ from its place of purchase; restaurant context must not overwrite the food provider's actual brand.

### Ingredient checklist

After restaurant intent is settled, classify the dish before nutrition lookup. A sufficiently specified fixed menu item proceeds to review. An underspecified customizable bowl, burrito, salad, or similar dish gets a focused checklist for that dish. Multiple dishes from the same restaurant retain separate dish IDs and checklists.

For “a chicken bowl from Chipotle,” only chicken is included from the description. Offer rice, beans, vegetables, salsa, cheese, sour cream, guacamole, lettuce, and “Something else” as editable composition prompts. These are a proposed bowl template, not a verified or exhaustive current menu. Verify template names and provider mappings against official/current sources during implementation; support free text for missing ingredients and local restaurants.

For “chicken, brown rice, black beans, no cheese,” prefill the three inclusions and retain cheese as explicitly excluded. Distinguish three states internally: included, excluded, and unspecified. A suggested option left untouched is not an assertion that the person said “no.” The checklist completes with an explicit review action confirming the selected composition; only confirmed inclusions reach lookup. Never add default toppings merely to make a bowl appear complete.

Let people change or remove any extracted ingredient. For a category such as “rice” without a variant, ask for a choice or retain “Not sure”; do not assume white rice. Allow multiple applicable choices rather than making rice/beans mutually exclusive without reason. “Not sure” and “Something else” lead to an explicitly uncertain item or a short text clarification, not guessed precise composition. A zero-ingredient draft must get a useful next action rather than an enabled empty log.

Confirm portions in the existing final food review after lookup. The checklist establishes composition, not exact serving amounts. “Double chicken” or “half the rice” must retain quantity intent through the checklist and resolve against the actual serving selected. Never count both a complete bowl entry and its ingredients for the same dish.

### Search and final review

With a restaurant selected, search the venue plus item first using the existing provider integration. Normalize known brand aliases, then rank restaurant-compatible candidates. Keep generic or uncertain matches in a clearly labeled fallback group; do not present another restaurant's item as an exact match. Allow removing the restaurant to broaden the query.

Exact prepared menu items can proceed to serving review. A configurable “build a bowl” action uses the checklist; not every result or restaurant search needs an extra step. Matching strategy must be measured against the actual provider catalog, including pagination, rather than assuming that a new restaurant filter or directory API exists.

Review shows the selected restaurant and each item's actual provider brand, serving, quantity, and a truthful match label: restaurant match, generic database match, or estimate. The existing `source: fatsecret` only establishes a database source, not an exact venue match. Missing database results and provider errors must not silently turn into a verified-looking restaurant item. Estimates require an explicit review choice and retain the estimated badge. Skip numeric confidence percentages.

## Client and server contract

Introduce a version 2 request/response contract on `parse-food`, gated by an explicit `schemaVersion: 2`. Keep legacy `{text} → {items}` callers compatible until the new client is released. Do not return clarification-only responses to clients that only understand food rows. New clients verify the response version before accepting guided results, so an older deployment cannot silently supply legacy guessed ingredients.

Proposed request fields:

- `schemaVersion`, `draftId`, `draftRevision`, transcript text.
- Optional restaurant `{id?, displayName, origin: manual|detected|confirmed}` and an explicit rejected interpretation when applicable.
- Optional structured clarification answer or checklist `{dishId, included, excluded, unspecified, quantityIntents, compositionConfirmed}`.

Proposed response states:

- `needs_restaurant`: ambiguous term/conflict, safe display wording, bounded interpretation choices.
- `needs_ingredients`: normalized restaurant, dish ID/type, extracted inclusions/exclusions, suggested categories/options, quantity intent.
- `ready`: confirmed context and resolved food rows with source, match kind, selected serving ID/description, quantity, and nutrition.

Every response echoes draft ID/revision. Treat restaurant names, transcripts and checklist inputs as data, never prompt instructions. Validate lengths, allowed state transitions, item/option counts, numeric ranges and response schema server-side. Revalidate user ownership/AI consent for each AI stage; keep existing rate limiting and add a bounded request/tool budget so clarification does not create an unlimited lookup loop.

Use shared typed helpers under `supabase/functions/_shared/` for intent schemas, restaurant normalization and candidate validation. Intent extraction runs before database resolution. The server only resolves confirmed ingredients. Candidate IDs must belong to returned search results, and resolved brand/serving metadata must be checked again after fetching details. Choose a specific valid serving instead of always index zero. If no suitable serving exists, return a reviewable unresolved/estimated state; do not manufacture serving precision.

For plain Search, extend the existing endpoint with optional restaurant context and additive match metadata while preserving the legacy results shape. Plain Search remains deterministic and usable without AI consent. Restaurant selection and alias matching must not secretly invoke the AI parser for Search-only users.

## State ownership and persistence

Add an observable `FoodLoggingContext` owned by `FoodLoggingView`, injected into Search and Talk. It holds restaurant selection, rejected/confirmed interpretations, active draft revision and per-dish composition. Changing context increments the revision, cancels in-flight lookups, clears stale results/pages, and invalidates any ready rows that depended on the old context. Retain the person's original transcript and checklist edits for correction.

Give Talk explicit capture, clarifying restaurant, clarifying ingredients, resolving, review, saving, and saved states. No path from clarification logs food. Back navigation restores the draft; retry preserves answers. Reuse existing partial-save tracking (`isSaved`), the shared `FoodSaveUndo`, meal/date selection, AI consent, and per-serving snapshot/quantity conventions. After a partial save, restaurant changes are locked until the current entry is finished or restarted. Saved rows stay excluded from retries; a new entry can explicitly keep the restaurant.

The first version needs no database migration for restaurant context: it is a session/draft input. Keep provider brand and external food identity unchanged when saving. If persistent venue history is added later, put optional venue/provenance metadata on each log snapshot with a corresponding local-store migration; do not relabel shared canonical food definitions to look restaurant-specific.

## Implementation sequence

1. **Baseline fixtures and catalog check.** Capture current parser behavior for ambiguous Chipotle descriptions, seasoning language, explicit exclusions, and successful Texas Roadhouse examples. Verify real provider candidates and serving variants using authorized test calls; distinguish catalog gaps from interpretation failures. Do not use fabricated nutrition as expected ground truth.
2. **Shared schemas and parsing stages.** Implement typed v2 intent/clarification contracts, alias handling, per-dish ingredient states, and deterministic validation. Add mocked-provider contract tests before altering lookup behavior.
3. **Restaurant-aware matching.** Implement shared query/ranking helpers, brand verification, candidate-ID validation, serving selection, and labeled fallback behavior. Keep legacy endpoint responses compatible.
4. **Session context and Search.** Add the shared control/picker, context-keyed cancellation/pagination, manual and detected state, clear/override behavior, and non-AI Search tests.
5. **Talk checklist and review.** Build clarification and checklist views, connect the v2 state machine, preserve exclusions/quantities through review, and retain correction/undo/partial-save behavior.
6. **Validation and rollout.** Deploy additive backend support first, verify with disposable fixtures, then enable the new client flow. Review actual native screens and run signed-in Search/Talk tests. Measure clarification completion, restaurant mismatch corrections, generic fallback rate, and latency without storing raw transcripts or personal meal content in analytics.

## Acceptance cases

- “Chicken bowl from Chipotle” identifies the venue and only chicken from the text, then asks for composition. No rice, cheese, salsa, or lettuce is silently added.
- “Chipotle chicken” without manual context asks restaurant versus seasoning. “Chicken with chipotle sauce” does not automatically pick the chain.
- A manually selected venue survives Search/Talk switches and overrides weak inference; an explicit conflicting venue gets a clarification.
- “Brown rice, black beans, no cheese” preserves inclusions and the cheese exclusion. Double/half quantities survive review and lookup.
- A named fixed item can remain one item. A confirmed ingredient-built dish never also logs an entire dish with overlapping macros.
- Texas Roadhouse descriptions that previously succeeded remain supported; generic meals without restaurants retain their normal path.
- Unknown/local restaurant names work as context without claims of verified menu coverage. Generic results and estimates are clearly differentiated.
- Clearing/changing the restaurant during a slow search cannot show stale rows, append pages from an old restaurant, or log a previously reviewed match under the new context.
- Changing the transcript/checklist after a request invalidates stale responses by draft revision. Back/retry preserve answers; closing the sheet and account changes clear them.
- Serving variants are selected explicitly. Quantity is applied once against per-serving macros, with no double scaling.
- AI consent denial leaves plain Search, manual entry and restaurant selection usable. Guided Talk cannot bypass consent or logging confirmation.
- Lookup/permission/network errors stay distinguishable from no results. No food logs are saved during clarification; save retry/undo keep the existing deduplication guarantees.
- Old clients still decode their responses; new clients reject incompatible guided responses. Native UI supports large text, VoiceOver labels, keyboard dismissal and 44-point actions.

## Review artifacts and limits

Three connected concepts in `marketing/restaurant-context-review-2026-11-06/` illustrate restaurant selection, ambiguous Talk interpretation, and a checklist with stated inclusions/exclusions. They follow the actual Daylight food logging capture, not a redesigned app shell. They are proposals, not native screenshots, verified menu listings, or nutrition evidence. Final food/portion review reuses the existing confirmation flow and is specified above rather than introducing a separate logging surface.


## Build and verification — November 6, 2026

The shared restaurant picker and session context are implemented in `FoodLoggingContext.swift`, `RestaurantLoggingViews.swift`, and the Search/Talk view models. Guided Talk uses the version-2 parser contract; plain restaurant Search remains non-AI. The checklist preserves included, excluded, and unspecified ingredients, allows custom additions, and resolves only confirmed inclusions. Final review shows verified restaurant matches, other database matches, or explicitly accepted estimates, plus editable actual provider servings. Existing save, partial retry, correction and undo paths are reused.

Hosted `parse-food` and `search-food` are deployed with JWT verification enabled. The legacy parser shape remains supported. No database migration is needed for this feature. Model-selected food and serving IDs are checked against actual provider responses; provider brand is preserved. Quantity multipliers are separated from weight-based item descriptions. Excluded ingredients returned with zero quantity during extraction are normalized without ever entering lookup.

Verification includes 13 deterministic backend contract tests, six native state tests, and keyboard UI tests on dedicated iPhone 17 Pro and iPhone SE simulators running iOS 26.5. UI tests assert the real keyboard's space key is present and check field/action frames and hit targets above the keyboard. The custom ingredient editor and Add/Review controls are fixed above the keyboard; parent chrome collapses during typing. A restaurant-change crash from reindexing a shrinking result array was fixed using a stable render snapshot.

The opt-in `scripts/restaurant-context.hosted.mjs` check uses a disposable account and real hosted providers. It verifies AI consent denial, ambiguous Chipotle clarification, restaurant-scoped Search, chicken/brown-rice/black-bean inclusions with cheese excluded, subsequent nutrition resolution, legacy parsing, and a six-ounce Texas Roadhouse sirloin at quantity one. The test account is removed in `finally`. No personal account or meal data is used.

Native keyboard captures are in `marketing/restaurant-context-review-2026-11-06/native/`. They use debug fixtures for layout; nutrition/catalog evidence comes from hosted tests, not these screenshots. Dictation continues through the existing speech pipeline; automated UI checks use typed Talk input. Real microphone recognition and physical-device keyboard variants still need a device smoke test. Restaurant catalog coverage can vary, so alternatives and estimates remain visible for review.

Validation commands:

```sh
node --experimental-strip-types --test scripts/restaurant-context.contract.mts
# Hosted check is opt-in; supply private CLI keys outside the repository.
node scripts/restaurant-context.hosted.mjs
xcodegen generate
# Run FootingTests/RestaurantLoggingTests and FootingUITests/RestaurantLoggingUITests
# with xcodebuild test against dedicated QA simulators, using ad-hoc signing.
```
