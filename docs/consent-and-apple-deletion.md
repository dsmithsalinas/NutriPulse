# AI consent and Apple-linked deletion

Implemented locally October 20, 2026. **Not deployed or published; no TestFlight build created.** The release remains 1.3.4 (299). The implementation below is tested source, not a claim that production has changed.

## AI consent

- AI food logging has its own explicit sheet naming Anthropic and FatSecret, explaining the food-description data flow, and preserving search, barcode, usual-meal and manual logging when declined. Microphone/Apple Speech permissions remain separate.
- `pulse_profiles.food_ai_consent_at` is nullable. Existing accounts start without food-parsing permission; Pulse permission never implies it. The existing owner-only policies and account-deletion cascade cover the new column.
- Food permission has no persisted grant cache. Loading/saving failures block parsing. Account switches, late responses and foreign rows cannot grant the next account permission. The app rechecks the server before each parse.
- `parse-food` and `coach-chat` enforce their respective stored permission under the authenticated owner's JWT before AI/provider use. Missing rows, failed lookups and missing schema fail closed. Pulse additionally requires that it is not disabled.
- Profile → AI food logging can revoke food parsing. Profile → AI data sharing can withdraw Pulse permission. Revocation stops subsequent requests; it cannot recall already transmitted requests. Failed saves stay on the sheet and show an error. A remote Pulse revocation invalidates the local consent state when the server rejects a stale request.
- Pulse's disclosure now includes meal notes, qualitative breakfast check-ins, approved memories, lighter-tracking context and relevant Strong Week/goals/experiment context.

## Account deletion

- Email-only users retain the ordinary deletion path and do not need Apple configuration.
- Apple-linked users can obtain a fresh native Apple authorization code at deletion time. This does not change the active Supabase account or retain refresh tokens from routine sign-in.
- The authenticated server exchanges the code with Apple, verifies the returned identity token's signature, issuer, audience, expiry, age and subject, and matches its subject to the trusted Apple identity on the current Supabase user. It then revokes the returned refresh token before deleting that user.
- A mismatch, token exchange failure or revocation failure never automatically deletes the Footing account. Error responses do not include codes, tokens, signing material or raw provider errors.
- Apple also requires a deletion option when a token/code is unavailable. The explicit **Apple confirmation unavailable?** option asks for a second destructive confirmation, deletes the authenticated Footing user's data without automatic revocation, and shows a link to Apple's manual-disconnection instructions on the signed-out screen. Automatic/manual modes cannot be combined in one request.
- Cleanup attempts all existing local outbox/meal caches and clears Pulse's cached settings. A local cleanup failure does not keep a remotely deleted user signed in. A response for an old account never signs a newly active account out.

## Required production configuration

Read-only inspection of secret **names** in `dcabdzuhuixlcgwavtsc` found all four absent:

| Server secret | Value needed |
| --- | --- |
| `APPLE_CLIENT_ID` | Native app bundle ID: `com.dustin.nutripulse.app` |
| `APPLE_TEAM_ID` | The Apple developer team owning the app; current release entitlements identify `G574NUGMU2` |
| `APPLE_KEY_ID` | Key ID of a Sign in with Apple-enabled signing key for that team/app |
| `APPLE_PRIVATE_KEY` | That key's PKCS#8 `.p8` contents; multiline and escaped-newline forms are supported |

Provision through a secure local file or the Supabase secrets UI, never source control or chat. This is a Sign in with Apple key, not an App Store Connect API key. No signing credentials were created, read, or transmitted in this implementation. The server generates a five-minute client secret per deletion flow. The `.p8` key stays server-side. Configuration alone does not establish that Apple code exchange/revocation works; a real disposable Apple-linked account check is still required.

## Rollout order and compatibility

1. Configure the Apple signing secrets and verify the team/key/client association.
2. Apply `supabase/migrations/20261021171951_food_ai_consent.sql`.
3. Deploy `parse-food`, `coach-chat`, and `delete-account` with their changed shared modules (`ai-consent.ts`, `apple-account-deletion.ts`, `apple-token-revocation.ts`).
4. Distribute a matching app build and publish `marketing/site-v2/public/privacy.html` together with the behavior it describes. `marketing/privacy.html` is now a redirect to the canonical policy, and the app links directly to `https://tryfooting.app/privacy`.
5. Verify fresh/declined/approved/revoked permissions and two-account isolation against deployed services. Check automatic Apple deletion, cancellation, wrong Apple identity, provider failure, email-only deletion, and the explicit manual-disconnection fallback using disposable accounts only.
6. Enter/reconcile App Store Connect privacy answers from the worksheet below; no live privacy labels were changed here.

**Compatibility:** once strict food consent is deployed, older app builds cannot parse until the account grants food permission from the new app. Older Apple-linked builds cannot supply the required confirmation or manual-fallback choice. Coordinate deployment with the matching release; do not treat the backend as an independent invisible update. Existing valid Pulse grants continue to work; accounts without Pulse consent no longer fall through on missing settings or query errors.

## Privacy disclosures prepared

The canonical policy draft covers notes, usual meals, breakfast check-ins, approved practical memories, lighter-tracking context, AI permissions, deletion paths, local caches, and actual iOS HealthKit read/write categories. The privacy manifest adds Other User Content, Customer Support and Other Data Types, and declares personalization for the categories used to tailor coaching. Its ten category identifiers were checked against Apple's current machine-readable schema. SDK manifests remain separate; the final App Store Connect answers must include applicable SDK practices.

Draft App Store Connect inventory (all marked **not used for tracking**):

| Category | Examples | Linked to account | Purpose |
| --- | --- | --- | --- |
| Health | Nutrition, water, body measurements, GLP-1 history/check-ins | Yes | App functionality; product personalization |
| Fitness | Workouts and connected activity signals | Yes | App functionality; product personalization |
| Name / email / user ID | Account and authentication | Yes | App functionality |
| Other user content | Pulse chat, meal notes, approved practical memories and free-text context | Yes | App functionality; product personalization |
| Customer support | Submitted feedback | Yes | App functionality |
| Other data | DOB, sex/activity/profile choices, preferences and consent/settings records | Yes | App functionality; product personalization |
| Product interaction | TelemetryDeck product signals without diary/chat content | No, per current manifest | Analytics |
| Crash data | Previous-session crash indicator | No, per current manifest | Analytics; app functionality |

## Validation

- Final simulator suite: **488 executed, 481 passed, seven optional live checks skipped, zero failures**. Includes nine new food-consent tests covering opt-in, revocation, unavailable reads, foreign rows, late saves/loads, account switches and remote revocation.
- Node contract suite: **18 passed**, covering independent server permissions, failure/missing-schema behavior, Apple deletion order and mismatches, manual fallback, RLS, independent grants/revocation and deletion cascade.
- Deno cryptographic/HTTP suite: **four passed**, with locally generated test keys and mocked Apple HTTP. Verifies client-secret signing, token signature/claims rejection and sanitized failures; no real Apple tokens or accounts used.
- All three changed Edge Functions pass Deno type checking. Website production build passes. Privacy plist parses and all ten category names match Apple's schema. `git diff --check` passes.
- No live account deletion, real Apple code exchange/revocation, migration, function deployment, policy publication, App Store metadata update or physical-device acceptance was performed.

## References

- [Apple token revocation and fallback guidance](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
- [Apple account deletion requirements](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Apple AI data-sharing requirements](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)
- [Apple privacy manifest categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)

## TestFlight rollout — October 21

The food-consent migration was applied as 20261021171951_food_ai_consent. Deployed with JWT verification retained: parse-food v12, coach-chat v34, delete-account v9. Apple signing-secret names were rechecked and all four remain absent; no automatic Apple revocation is claimed. The release is 1.3.5 (300), with onboarding and Today fixes. Historical validation/status above records the original implementation pass; release archive/upload evidence is tracked separately.
