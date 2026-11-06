# Restaurant context logging concepts

November 6, 2026. Three connected flow concepts for review, grounded in the actual Footing food logging capture at `marketing/social/launch-collection-2026-10-20/assets/app-talk.png` and the current Daylight tokens. Generated concept images; not native screenshots or implemented screens.

| Step | Concept | Purpose |
| --- | --- | --- |
| Manual context | [Restaurant picker](restaurant-picker.png) | Select a restaurant once for Search and Talk in the current logging session. Custom names remain possible. |
| Automatic recognition | [Talk clarification](talk-restaurant-clarification.png) | Resolve an ambiguous “chipotle chicken” description before interpreting the food. |
| Customizable meal | [Ingredient checklist](ingredient-checklist.png) | Preserve stated ingredients and exclusions; add optional ingredients only by explicit choice. |

These are steps in one proposed flow, not competing style alternatives. The checklist illustrates a more detailed transcript so that the prefill/exclusion behavior is visible. An entry that only says “chicken bowl” would prefill only chicken. Templates, unknown portions, custom ingredients, and final nutrition review are specified in the [implementation plan](../../docs/restaurant-context-logging-plan.md); not every state appears in these three frames.

Restaurant names and suggested bowl options illustrate interaction, not verified menu coverage. No live nutrition or catalog assertions are made. The existing food/portion confirmation screen remains the final step before saving.

Review status: approved and implemented. The PNG concepts above remain the original design references.

Native iPhone SE keyboard verification captures:

- [Restaurant picker](native/restaurant-picker-keyboard-se.png)
- [Talk input](native/restaurant-talk-keyboard-se.png)
- [Custom ingredient and review action](native/restaurant-checklist-keyboard-se.png)

These native captures use debug fixtures for layout. Keyboard tests also pass on iPhone 17 Pro. Hosted catalog checks use a disposable account; results and limits are recorded in the implementation plan. No database migration was needed for restaurant context.
