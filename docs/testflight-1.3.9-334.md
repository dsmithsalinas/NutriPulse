# Footing 1.3.9 (334) — submission candidate

Prepared November 16, 2026 from pushed commit `29df570e9bb90e4cf5a9dcdf81c3b0cee7d247da`. Owner requested password-reset fixes and an iPhone-only initial release. The archive uses a clean `git archive HEAD` source snapshot, with existing private build configuration copied locally; unrelated working-tree changes are excluded. Build 333's recorded source included uncommitted changes, so 334 replaces it with committed, reproducible source.

## Changes and validation

- Password-reset callbacks route to recovery before sign-in events can open the app home. Invalid/expired callbacks offer retry and return-to-app controls.
- Privacy corrections, membership, widget, onboarding and medication fixes remain included.
- Release archive succeeded. Focused acceptance: **21 passed, zero failed/skipped** on iOS 27.2 (16 unit checks, three membership UI checks, two cold/warm recovery URL UI checks).
- Results: `build/Release334-acceptance.xcresult`. Archive/export/upload evidence: `build/TestFlight-1.3.9-334/`.
- Distribution IPA signatures, app/widget 334 versions, shared App Group, debugger entitlement absence, bundled manifest equality, real product identifier and absence of private keys/local StoreKit fixtures all verified. IPA SHA-256: `18da22fdf8e2101f6da7a560a5c60a87e4ec3e4dde415d49d1736b53580bcc02`.
- Apple accepted the upload November 16 at 9:25:59 PM Pacific. Apple processed build 334 as Ready to Submit. App Store version 1.3.9 retains build 334 after reload.

## Expiration acceptance

Disposable Jordan account: Apple subscription `Sandbox`, status **2 (expired)**, revoked false, expires_at **2026-11-16T20:39:14Z** (12:39:14 PM Pacific). Latest Apple verification recorded at 2026-11-17T05:15:03.520Z; read-only backend check at 2026-11-17T05:18:08.939Z confirms active=false. Membership snapshot has no premium/subscription expiration or founding grant. The user confirmed Pulse/AI food paywalls, inactive membership, and retained free tracking, food search and saved records. No database expiration was edited to manufacture this result.

## Saved review preparation

- App and subscription notes updated with completed purchase/reopen/restore/cancellation/expiration acceptance and persisted after reload.
- Existing required subscription image retained; its read-only local StoreKit capture remains disclosed.
- App version **1.3.9 (334)**, subscription group and monthly product are staged together. Apple shows **Items Ready to Submit (3)** and an enabled Submit for Review button, with no validation blocker displayed. Submitted November 16, 2026 at the owner’s explicit request. Apple confirmed **3 Items Submitted** and app version **Waiting for Review**. Submission ID: `b9130730-db70-4843-8bc6-af435cf12e3d`.
- Owner selected iPhone only; Mac and Vision Pro availability disabled and persisted. Manual release retained.
- Public enforcement remains off and founding campaign remains closed, 0/50 claims, no grants. Production notification routing is already saved; production API delivery is a post-release check.

## Remaining acceptance and release actions

- Upload, processing, persisted binary selection and combined draft validation are complete. Manual release was verified selected immediately before submission. App/subscription/group are submitted; public activation has not occurred.
- Owner confirmed password reset worked on build 334 before authorizing submission.
- The isolated iOS 26.5 StoreKit check was rerun and still fails at `SKTestSession.buyProduct` with `notEntitled`, before Footing transaction sync. The same check passes on iOS 27.2 and physical sandbox lifecycle acceptance passed. A [firsthand Apple Developer Forum report](https://developer.apple.com/forums/thread/826971) describes iOS 26.5 CLI StoreKit configuration propagation failures; this is supporting context, not proof of this failure's cause. No app entitlement or verification protection was altered to mask the test failure. Result: `build/Release334-StoreKit26-5.xcresult`.
- App version/subscription/group submitted together. Await Apple’s decision; disable streamlined purchasing when the approved binary permits it. Follow `membership-launch-2026-11-15.md` for coordinated activation and post-release production verification.
