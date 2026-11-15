# Footing premium membership

Prepared November 14; backend deployed November 15, 2026 from pushed commit `625956f`. The premium migration and four Edge Functions are live. Native membership code is available in TestFlight 1.3.9 (326); revised policy pages and the public App Store release remain pending. Global premium enforcement and founding claims remain off; only the explicitly allowlisted disposable sandbox account uses prelaunch enforcement.

## Product behavior

- Free: manual tracking, food search/barcodes, saved meals, Health integration, practical tools and access to existing records. Account deletion, consent/privacy controls and support remain available. Generated advice is never needed to read past advice.
- Premium: Pulse conversations, generated weekly outlooks/recaps and AI food parsing. Both client preflight and server enforcement apply; a modified client cannot declare itself premium.
- Monthly subscription: US $2.99, localized price from StoreKit. Product `com.dustin.nutripulse.premium.monthly`. No Apple introductory offer is used for founding access.
- Founding membership: first 50 confirmed accounts to explicitly claim, one claim per account, three calendar months from server claim time. A claim never calls StoreKit, collects payment details, starts a subscription or renews. Expiry retains free tracking and records; the member may choose a subscription afterward. An active founder is not offered a purchase during the free period.
- Claims serialize on a campaign row. Retries return the original dates. The campaign's aggregate lifetime count is not decremented on account deletion, so places cannot be recycled. Deleting an account removes its private grant; recreating an account does not restore it.
- Initial included allowance: 60 Pulse requests (including weekly guidance) and 60 AI meal requests per UTC calendar month. Attempts/retries count; unused requests do not carry over. The server also limits aggregate premium AI operations to 10,000 per UTC month. These are request-volume controls, not a dollar spending guarantee. Per-request context/output bounds and existing hourly limits still apply. Revisit actual unit costs before expanding limits.
- Privacy and AI-sharing consent remain independent of billing. A purchase or free claim never grants AI consent or re-enables Pulse.

## StoreKit and ownership

`MembershipStore` loads only the monthly auto-renewable product, handles purchase/cancel/pending, listens for transaction updates and purchase intents, retries unfinished purchases, restores current entitlements and exposes Apple's subscription-management sheet. Sign-in and an explicit user choice precede any purchase, including outside-app intents. Purchases carry the authenticated Footing UUID as `appAccountToken`.

The server fetches transaction information and current subscription status from Apple. Apple Server Library 3.1.0 supplies the API client and model validators. Its MIT-licensed signed-data verifier is vendored with a narrow Supabase runtime compatibility adapter; it verifies transactions, renewals and notifications against pinned public Apple Root CA G2/G3 certificates, with online certificate checks. See the November 15 notification fix below. It verifies app/bundle, product, environment, purchase type and account token. The device sends a transaction ID and environment, never an entitlement boolean. Original transaction ownership cannot transfer between Footing accounts.

Notifications trigger an authoritative status refresh instead of trusting event arrival order. Replayed or older responses cannot overwrite newer stored state. Refund/revocation removes paid access; canceled renewal retains access until expiry. Billing retry alone does not grant access; grace requires an active grace status and signed grace expiration. Paid verification is refreshed on status requests after 15 minutes and is never accepted past 24 hours without a new check. Unavailable membership lookups fail closed for AI while free functionality remains available.

Deleting Footing does not cancel an Apple subscription. Both deletion dialogs warn about this. Apple billing is managed with Apple. Account deletion cascades private subscription rows. A purchase still tied to a deleted Footing UUID cannot silently attach to a new account; support must verify any recovery request. Do not implement reassignment based only on a submitted transaction ID.

Production and sandbox transactions use separate keys in the table. Sandbox access is accepted only for explicitly allowlisted Footing UUIDs. Allowlisted accounts also receive prelaunch premium enforcement in status and AI endpoints, so the real paywall and quota flow can be tested while `MEMBERSHIP_ENFORCED` stays off for everyone else. Founding claims still require the global launch flag and open campaign. Never set a general sandbox-access flag for all production users. Local Xcode StoreKit transactions are rejected by the deployed verifier and are used only with injected local test repositories.

## App Store Connect draft created

- Group: **Footing premium**, ID `22580786`, English (U.S.) display name configured.
- Product: **Footing premium monthly**, Apple ID `6834984644`, one month, US price $2.99; Apple's localized price equivalents saved.
- English display name: **Footing premium**. Description: **Pulse coaching, AI food logging, and weekly guidance.**
- Family Sharing is off. Purchase options are single-seat and App Store only; multiseat purchases are off.
- Status: **Prepare for Submission**. No review submission or customer billing was initiated. United States availability is configured at $2.99 for testing; the review screenshot remains to be completed.
- Streamlined purchasing is still on. Apple rejected disabling it because no approved binary includes PurchaseIntent yet. This implementation now listens to PurchaseIntent; disable streamlined purchasing after the first eligible binary is approved. Keep outside-app promotions and offer campaigns off meanwhile.
- Paid Apps Agreement still requires the owner's banking/tax information. This implementation does not submit financial/tax forms.

[Product draft](https://appstoreconnect.apple.com/apps/6789967509/distribution/subscriptions/6834984644), [subscription group](https://appstoreconnect.apple.com/apps/6789967509/distribution/subscription-groups/22580786).

## Server configuration

These are new **In-App Purchase / App Store Server API** credentials, obtained from App Store Connect → Users and Access → Integrations → In-App Purchase. They are different from the Sign in with Apple deletion key; do not reuse `APPLE_PRIVATE_KEY` or change deletion configuration.

| Setting | Value |
| --- | --- |
| `APP_STORE_ISSUER_ID` | `f2f9bd13-1260-4024-81d2-e0d92a55db01` |
| `APP_STORE_KEY_ID` | `887N4J9K9Y` — Footing purchase verification |
| `APP_STORE_PRIVATE_KEY` | Actual multiline PKCS#8 `.p8` key, server-only |
| `APP_STORE_SANDBOX_USER_IDS` | Comma-separated Footing UUIDs for dedicated sandbox/reviewer accounts; empty by default |
| `MEMBERSHIP_ENFORCED` | `true` only for the approved coordinated launch; absent/false preserves beta AI access |

New keys must be stored outside the checkout and provisioned securely. Do not paste keys, purchase payloads or authorization tokens into chat/logs. Creating a new API credential needs action-time owner approval. The previous authorization for the Apple sign-in deletion key does not authorize a new In-App Purchase key.

On November 14, 2026, the owner explicitly approved creation and configuration of the separate **Footing purchase verification** key. Apple shows it active and downloaded. Its private file is stored outside the repository at `/Users/dustinsmith-salinas/.config/footing/apple/SubscriptionKey_887N4J9K9Y.p8` (directory `0700`, file `0600`); the Downloads copy was moved. Arrange an independent secure backup because Apple permits only one download. Local EC P-256 key validation and ES256 sign/verify passed. All three hosted secret SHA-256 digests matched the intended values in Footing project `dcabdzuhuixlcgwavtsc`. The separate Sign in with Apple deletion key/configuration was not changed.

A read-only lookup using a deliberately nonexistent transaction ID returned sandbox HTTP 404 / Apple error `4040010` (transaction not found), establishing sandbox credential acceptance. The same production lookup returned HTTP 401. Follow-up investigation reproduced this result and confirmed Footing 1.0 remains **Prepare for Submission** in App Store Connect. An [Apple App Store Commerce Engineer explains](https://developer.apple.com/forums/thread/806452) that production API access is locked until an app has a production release. This identifies the pre-release access prerequisite as the explanation for this result; it is not evidence of a malformed key, and no credential rotation is indicated. Successful production access is still unverified and must be checked after the first production release. Sandbox testing can proceed before then. This probe does not verify a real purchase, receipt chain, renewal, restore or refund. No migration, code deployment, notification configuration or billing activation occurred. `MEMBERSHIP_ENFORCED` and `APP_STORE_SANDBOX_USER_IDS` were absent after provisioning.

`membership` requires a Supabase JWT and verifies the current auth user. Its actions are status, claim and sync; no caller-supplied user ID is accepted. `app-store-notifications` is the one public webhook, with `verify_jwt=false` because Apple signs the payload rather than providing a Supabase JWT. All new tables and RPCs are restricted to service_role; there are no client write grants, user-metadata grants or exposed security-definer functions.

## Coordinated rollout checklist

1. Review the implementation, included AI allowances, screen captures and policy drafts. Keep unrelated working-tree changes out of the release. Commit/push approved source before deployment, following `daylight-redesign.md`.
2. Owner completes banking/tax details; choose app and subscription territories. Set the new app version to manual release so purchase settings can be finalized after approval and before public availability. Finish the subscription review screenshot and reviewer instructions. Submit the first subscription with the new app version, not on its own.
3. Key creation and the three server secrets are complete; sandbox credential authentication passed. Production HTTP 401 is expected while Footing has no production release; recheck production access after the first release (see server configuration). Set only dedicated synthetic sandbox/reviewer UUIDs in `APP_STORE_SANDBOX_USER_IDS` for live sandbox tests; the allowlist is currently absent.
4. Apply `20261115182443_premium_membership.sql`. It creates a closed campaign (`enabled=false`, `claimed=0`). No existing users are automatically enrolled or charged.
5. Deploy `membership` with JWT verification, `app-store-notifications` with Apple signature verification, and updated `coach-chat`/`parse-food`. Leave `MEMBERSHIP_ENFORCED` unset initially. Inspect grants/RLS and deployed source after rollout.
6. Configure production and sandbox App Store Server Notifications V2 URLs to `https://dcabdzuhuixlcgwavtsc.supabase.co/functions/v1/app-store-notifications`. Send Apple's sandbox test notification and check its result; perform the production notification test after production API access unlocks with the first release. Review failures without recording signed purchase bodies.
7. Use an isolated test database/project for founding-claim load tests so real launch places are not consumed. Run real Apple sandbox purchase, pending approval, cancellation, renewal, expiration, billing retry, grace, refund, restore, sign-out/account-switch and notification replay tests with synthetic accounts. A local Xcode transaction cannot validate the live Apple chain/API/OCSP path.
8. Coordinate server enforcement with the new binary and notify existing beta users before changing access. Open claims with `update public.membership_campaign set enabled=true where id=true;` and enable `MEMBERSHIP_ENFORCED=true` only at the agreed launch. Do not reset or decrement claimed places to simulate availability in production.
9. Publish the revised privacy/terms sources, reconcile App Store privacy labels with Purchase History, and verify live URLs. Build/upload the approved app and complete App Review. No new code is active merely because the subscription draft exists.
10. After the eligible binary is approved and before manually releasing it, disable streamlined purchasing and verify the setting. Keep Family Sharing/multiseat off unless account/seat entitlement handling is deliberately added.
11. After the first production release, recheck App Store Server API access and production test-notification delivery. Verify a real production transaction through the full entitlement flow; if HTTP 401 persists after release, collect sanitized request diagnostics for Apple Developer Support. Do not rotate credentials solely because of the expected pre-release 401.

Rollback: unset `MEMBERSHIP_ENFORCED` and close the campaign (`enabled=false`). Preserve subscription records, webhook processing, cancellation/restore controls and paid access history. Do not delete customers' Apple products or reset claim counts.

## Validation

Commands (from the repo unless specified):

```sh
node --experimental-strip-types --test scripts/membership*.mts scripts/pulse-chat.contract.mts scripts/strong-week.contract.mts
python3 scripts/membership-postgres-test.py
npx --yes deno test scripts/apple-store.contract.test.ts
npx --yes deno check supabase/functions/coach-chat/index.ts supabase/functions/parse-food/index.ts
# Run `npx --yes deno check index.ts` in each new function directory to use its lockfile.
```

The Postgres test creates and removes its own isolated Docker container; it never touches production or an existing local database. It verifies that 60 genuinely concurrent claims yield exactly 50 grants, and 24 concurrent quota requests yield exactly two allowed operations at a limit of two. SQL contract tests cover privileges, expiry, retries, stale status, refunds, quotas and account-deletion cascades. Native tests use an injected membership repository and Apple's local StoreKit test configuration; UI previews use fictional accounts and never claim a real place or charge a customer.

Validation on November 14: the full native suite executed 566 tests (557 passed, nine optional live checks skipped, zero failures); three membership UI tests passed, including the localized $2.99 price/terms and largest accessibility text. The combined backend suite passed 58 tests. Two official-library/root-certificate tests passed. The isolated Postgres concurrency checks passed. All four changed/new Edge Function entrypoints type-check, the website production build passes and the privacy plist parses. Both Debug and Release simulator builds compile. The final focused rerun passed all eight membership unit tests and three UI tests. Screenshots from the native result bundle were inspected; the review capture is `build/MembershipPriceReview/D8A2F4DC-4CD3-4086-96FD-9C237E1C1F1B.png`. Local StoreKit covers synthetic transaction sync/finish and canceled/pending result handling; it does not establish real Apple sandbox purchase, restore, renewal or refund delivery.

Live App Store sandbox purchase validation and deployment remain pre-release checks. Production API authorization is a post-release check because Apple gates production access on a production release. Server key provisioning is complete. The earlier acceptance of untested Apple-linked account deletion is not evidence that subscription billing has been tested.

References: [Apple Server Library](https://github.com/apple/app-store-server-library-node), [Apple purchase verification](https://developer.apple.com/documentation/storekit/verificationresult), [StoreKit purchase intents](https://developer.apple.com/documentation/storekit/purchaseintent), [Supabase database function security](https://supabase.com/docs/guides/database/functions).

Production-401 investigation: repeated the read-only lookup with a freshly signed five-minute ES256 JWT; production returned 401 with an empty body and sandbox returned 4040010 using the same token. Confirmed the key remains active in App Store Connect. Reviewed the implementation: requests use their explicit Production/Sandbox environment, sandbox accounts require the dedicated allowlist, and Apple-signed transaction environment is checked. No generic 401-to-sandbox fallback was added. No secrets, billing settings or deployed code changed during this investigation.

## Backend deployment — November 15, 2026

- Pushed source commit `625956f` before hosted changes. Applied the reviewed `premium_membership` migration via the Supabase migration API. The local filename is reconciled with the hosted migration timestamp: `20261115182443_premium_membership.sql`.
- Deployed `membership`, `app-store-notifications`, `coach-chat`, and `parse-food` to Footing project `dcabdzuhuixlcgwavtsc`. After the sandbox secret update their reported versions were 2, 2, 39 and 23 respectively; membership/AI endpoints retain JWT verification, and the Apple signature-authenticated webhook has JWT verification off.
- The owner selected the existing, confirmed Jordan disposable account. Its UUID is the sole `APP_STORE_SANDBOX_USER_IDS` entry; the hosted secret digest matched. `MEMBERSHIP_ENFORCED` remains absent. This account alone exercises the paywall and membership AI checks; other beta users retain beta access.
- Campaign verified `enabled=false`, `claimed=0`. All five new tables have RLS and no client read/write grants. All four RPCs are invoker-rights with no authenticated-client execute permission. Security advisor reports informational no-policy notices for deliberately server-only tables; no warning/error findings were returned.
- 59 backend contract tests passed; all four affected entrypoints type-check. Hosted membership rejects unauthenticated calls (401); a forged Apple webhook payload is rejected (503), with no entitlement granted. The disposable account's database snapshot has no founder or subscription grant.
- Saved the sandbox notification URL in App Store Connect and confirmed it survives page reload: `https://dcabdzuhuixlcgwavtsc.supabase.co/functions/v1/app-store-notifications`. Apple Request a Test Notification returned `4040007` (notification URL not found) on two checks despite the persisted UI setting. This initial URL-propagation issue is now resolved; signed delivery verification is recorded below. Production URL configuration remains pending.
- No new TestFlight build/upload was made: the owner requested widget and other bug fixes first. The installed build predates native membership UI. Real sandbox purchase/restore/renewal/expiration/refund remain untested; signed TEST-notification delivery is now verified below. Product availability/review metadata and Paid Apps Agreement status also require a fresh check before purchase testing.

When the updated TestFlight build is ready, sign into Footing with the selected disposable account, open Profile → Your membership, confirm the localized monthly price, and run the sandbox purchase. TestFlight purchases use Apple's sandbox and do not charge real money. Check premium access, force-quit/reopen, then restore on the same Footing account. Verify transaction/environment/account ownership on the backend before testing cancellation/expiration. Founding claims remain closed during these tests; do not consume a real launch place.

## Sandbox notification delivery resolved — November 15, 2026

Apple's sandbox Request a Test Notification now reports `SUCCESS`. A real Apple-signed TEST payload also returns HTTP 200 / `ok` from the hosted endpoint. The initial `4040007` cleared after the saved URL became available to Apple's API; subsequent 503 responses exposed actual runtime compatibility failures.

The hosted runtime lacks Node X509 raw/toString/verify/infoAccess support ([Supabase issue](https://github.com/supabase/edge-runtime/issues/761)). The final implementation vendors Apple's MIT-licensed v3.1.0 verifier, retaining Apple's chain/purpose/date checks, OCSP revocation verification, model validators and app/environment checks. The adapter preserves original DER and uses native SHA-2 signature primitives rather than CPU-heavy pure-JS elliptic-curve verification. Equivalent curve metadata is derived from the actual PEM key, not the JWT header; no JWK export or missing hosted X509 methods are needed. Strict jsonwebtoken algorithm/curve checks stay enabled, including for outgoing API signing. No signature/revocation check was disabled. Source provenance and license are next to `apple-signed-data-verifier.ts`.

Four crypto contract tests pass. The live acceptance script verified the real Apple TEST while simulating the missing runtime methods and NIST curve aliases; wrong app, wrong environment, tampered signature and unavailable OCSP all failed closed. The official SDK accepted a normalized signing KeyObject and Apple's sandbox authenticated a read-only nonexistent-transaction lookup (4040010). The full backend contract suite passes 59 tests. Temporary verbose diagnostics and response headers were removed; retained logs contain only bounded status/classification, never signed payloads or raw exceptions.

`membership` and `app-store-notifications` were redeployed with the compatibility fix from pushed source. Production remains subject to Apple's first-production-release prerequisite. This verifies TEST notification transport and cryptography, not purchase/restore/renewal/refund handling; those require the updated app and real sandbox purchases. Global enforcement remains off, the sandbox allowlist remains restricted to the selected disposable account, and founding claims stay closed.

Reproduce with a newly obtained, privately stored Apple TEST payload (never commit the file):

```sh
npx --yes deno run --node-modules-dir=none --no-lock --allow-read --allow-net scripts/apple-store.live-test.ts /secure/apple-test.json
```

Final hosted verification: `membership` v8 is ACTIVE with JWT verification on; `app-store-notifications` v11 is ACTIVE with JWT verification off and Apple signature verification on. Both downloaded sources contain the PEM-based adapter. A fresh Apple TEST after diagnostic cleanup again reported SUCCESS; a forged payload remained rejected and temporary headers were absent. Campaign remains closed with zero claims; subscription rows remain zero. Global enforcement is absent and the sole sandbox allowlist entry is unchanged.

TestFlight update: native membership and the widget/onboarding/medication fixes were archived as 1.3.9 (326) from pushed commit `03e9d2b`, signed/exported, and accepted by Apple on November 15 at 11:17 AM Pacific. Processing/internal availability and the iPhone test steps are tracked in `docs/testflight-1.3.9-sandbox-check.md`. The owner-only Paid Apps Agreement banking/W-9 step was still pending at the pre-upload check.

Apple finished processing 1.3.9 (326): Ready to Submit, internal Early Access group, one invitation. The owner can install it in TestFlight. No public App Store release or external beta submission was performed. Sandbox purchase availability still requires the Paid Apps Agreement to become Active after owner banking/W-9 completion.
