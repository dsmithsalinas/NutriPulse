# Membership launch configuration — November 15, 2026

Prepared for Footing project `dcabdzuhuixlcgwavtsc`, app `6789967509`, product `com.dustin.nutripulse.premium.monthly`, build 1.3.9 (330). This is the activation runbook, not an instruction to activate during preparation. Expiration acceptance and public release are still pending.

## Verified preparation

| Setting | Current state | Intended launch state |
| --- | --- | --- |
| Production notification URL | Saved in App Store Connect and persisted after reload | Keep configured |
| Sandbox notification URL | Saved; fresh Apple TEST reports SUCCESS | Keep configured |
| `MEMBERSHIP_ENFORCED` | Absent; public beta enforcement off | `true` at coordinated launch |
| `membership_campaign.enabled` | `false` | `true` at coordinated launch |
| Campaign `claimed` / grant rows | `0` / `0` | Preserve all accounting; cap at 50 |
| Sandbox allowlist | Jordan test + Marcus reviewer only | Keep these two disposable accounts; no general sandbox fallback |
| App version release | Manual; 330 selected | Release only after final checks |

Both notification URLs point to:

`https://dcabdzuhuixlcgwavtsc.supabase.co/functions/v1/app-store-notifications`

The current App Store Connect URL dialog exposed no notification-version selector. The backend handles signed V2 payloads only. A successful TEST establishes transport and signed-V2 handling, but Apple sends TEST regardless of the configured notification version; actual production subscription-event delivery still needs verification after release.

Hosted source was downloaded and all four entrypoints match the checkout exactly:

| Function | Version | Active | Supabase JWT |
| --- | --- | --- | --- |
| membership | 9 | Yes | Required |
| coach-chat | 40 | Yes | Required |
| parse-food | 24 | Yes | Required |
| app-store-notifications | 12 | Yes | Off; Apple signature/chain/revocation verification authenticates delivery |

The three purchase-key secrets are present; the sandbox allowlist digest matches exactly the two disposable UUIDs. All four membership RPCs remain invoker-rights and are not executable by anon/authenticated clients. No schema or Edge Function deployment was needed for this preparation.

## Launch behavior

- Premium gates Pulse, generated weekly guidance and AI food parsing on both client and server. Free tracking, search/barcodes, saved meals, Health integration, saved records, privacy controls and deletion remain available.
- Monthly price is US $2.99 from StoreKit. Allowances are 60 Pulse and 60 AI meal requests per UTC calendar month; weekly guidance uses Pulse allowance and retries count.
- Founding membership goes to the first 50 confirmed accounts that explicitly claim. This counts claims, not downloads. Each grant lasts three calendar months from server claim time, without payment details, StoreKit enrollment or automatic billing.
- The claim RPC serializes the campaign row to enforce the cap, is idempotent for an existing grant, and excludes active subscribers. Account deletion does not return a place. Never reset/decrement `claimed` for tests or rollback.
- An active founder sees an access-through date instead of a Subscribe button. AI-sharing consent remains separate from membership.

## Gates before activation

1. Finish Jordan's actual expiration test after November 16, 2026 at 12:39:14 PM Pacific (20:39:14 UTC), subject to Apple's current state. Verify premium turns off, paid AI is gated, and saved records/free features remain usable. Update review notes that currently say expiration is pending.
2. App and first subscription pass review; keep manual release. Reviewers can use the named sandbox-allowlisted account while the public beta and founding campaign remain off.
3. Confirm US territory and $2.99 monthly price, current agreements, and disable streamlined purchasing once Apple permits it for the approved binary. Keep Family Sharing/multiseat off. Decide untested Mac/Vision availability separately.
4. Notify existing beta users before their AI access changes. Install 330 for final smoke checks. Isolated founding concurrency tests already passed; do not consume any real campaign place for a prelaunch test.

## Coordinated activation — NOT RUN

Use only the Footing project above. Immediately before the planned manual release, recheck campaign counts, deployed function/JWT settings, secrets and sandbox delivery. Commit/push any source changes before deployment. The commands below change hosted access when explicitly executed; they are staged here only.

First open the campaign, preserving its counter. While the global flag is off, the Edge Function still rejects claims:

```sql
begin;
select enabled, claimed from public.membership_campaign where id = true for update;
update public.membership_campaign set enabled = true where id = true;
select enabled, claimed from public.membership_campaign where id = true;
commit;
```

Then enable the common server flag for membership, Pulse and AI food parsing:

```sh
supabase secrets set MEMBERSHIP_ENFORCED=true --project-ref dcabdzuhuixlcgwavtsc
```

Supabase makes secret updates available without code redeployment. These two operations cannot be atomic across Postgres and function secrets. Keep the interval short; if the flag operation fails, close the campaign again and verify the held state. Do not manually release until authenticated membership status and AI gating reflect the intended settings. Keep the two-account sandbox allowlist unchanged.

Verify authenticated membership status shows `enforced=true`. An eligible non-premium user should see the founding offer while places remain; an active subscriber/founder should retain access. Check claim confirmation on an actual eligible founding member only when the campaign is genuinely open. Observe the counter increment once, a three-calendar-month expiration and no Apple transaction. At capacity, the offer disappears and the monthly subscription remains optional. Do not ask a reviewer to use up a launch place.

Manually release the approved binary at the coordinated launch. As soon as Apple unlocks production access, run the production notification check and verify a real production subscription transaction, environment, owner and entitlement. Do not interpret sandbox success as production success.

## Repeatable notification checks

```sh
node scripts/apple-notification-check.mjs Sandbox
node scripts/apple-notification-check.mjs Production
```

The script uses the existing Footing purchase key outside the repo at `~/.config/footing/apple/SubscriptionKey_887N4J9K9Y.p8`. It requests only a TEST and polls Apple's delivery result. It does not change billing, subscriptions or entitlements; JWTs, private keys, test tokens and signed payloads are never logged. Exit 0 means delivery SUCCESS; exit 2 means an API error or delivery not confirmed within the bounded polling window. Exit 1 means invalid usage or local/connectivity failure.

Preparation results: sandbox request HTTP 200, delivery SUCCESS; production request HTTP 401. Apple's Commerce Engineer states production API access is unavailable before a production release. This is consistent with Footing's current state, not proof that post-release credentials/delivery will work. Retry after first release. If 401 persists, investigate sanitized diagnostics with Apple rather than adding a generic production-to-sandbox fallback or weakening verification. Delivery failures should retain the receiver and existing entitlement history while investigated. Inspect notification history if events were missed; never log signed payloads.

## Rollback — NOT RUN

First return public AI access to the prelaunch beta behavior:

```sh
supabase secrets set MEMBERSHIP_ENFORCED=false --project-ref dcabdzuhuixlcgwavtsc
```

Then stop new founding claims:

```sql
update public.membership_campaign set enabled = false where id = true;
select enabled, claimed from public.membership_campaign where id = true;
```

Verify a non-allowlisted account reports `enforced=false`; the two test/reviewer accounts remain enforced by design. Close the campaign even if the flag operation fails. If either step fails, report the partial state and resolve it before release. Existing founding grants, purchase records and claim count must remain intact. Keep notification processing, Restore purchases and Apple subscription management available. This rollback does not cancel Apple subscriptions or refund payments.

## References

- [Apple notification URL configuration](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/enter-server-urls-for-app-store-server-notifications/)
- [Apple TEST status API](https://developer.apple.com/documentation/appstoreserverapi/get-test-notification-status)
- [Apple Commerce Engineer on pre-release production API access](https://developer.apple.com/forums/thread/806452)
- [Supabase secret updates](https://supabase.com/docs/guides/functions/secrets)
