# Footing 1.3.9 (330) — final privacy candidate

Prepared November 15, 2026 from pushed source commit `12d6163da43649f672e42f6d593007da1b1d2230`. The git-derived build number was fixed at 330 before project generation and archiving; later documentation commits do not change this sealed archive.

## Scope

The only app-source difference from TestFlight 1.3.9 (326) is `NutriPulse/PrivacyInfo.xcprivacy`: sensitive preferences and other diagnostics are declared; name includes personalization; product interaction covers account-linked AI allowance counters as well as analytics. The bundled TelemetryDeck manifest supplies the unlinked Device ID declaration. The combined disclosures match the 14 App Privacy categories published in App Store Connect.

Widget, onboarding, medication, membership, StoreKit, and founding-flow application code is unchanged from 326. Global membership enforcement and the founding campaign remain off; no Edge Function source deployment is part of this build preparation. The sandbox allowlist now contains the two disposable test/reviewer accounts only.

## Validation and artifacts

- Signed Release archive and App Store distribution export succeeded.
- The exported app and widget both report 1.3.9 (330); both signatures validate and both share `group.com.dustin.nutripulse`.
- The distribution IPA has no debugger entitlement, private `.p8` key, or local `.storekit` fixture. DEBUG membership-preview entry points are absent; the real monthly product identifier remains present.
- The exported privacy manifest matches source exactly, including the corrected categories and linked-usage declaration.
- All three membership UI checks passed on iOS 27.2: local StoreKit US $2.99 price/renewal terms, readable founding offer/free features, and no Subscribe button for an active founder.
- IPA SHA-256: `d2d6fc2cfb5410792092fec513b2b0e9dd6c325133bf979b1ad996652ff1ee62`.
- Artifacts: `build/TestFlight-1.3.9-330/Footing.xcarchive`, `export/Footing.ipa`, logs, verified export and `release-verification.json`.
- Results: `build/SubscriptionReview-330.xcresult`.

## Subscription review materials

The monthly subscription retains its existing group/product, one-month duration, US $2.99 price and US availability. English (US) display name/description are configured; Family Sharing and multiseat purchasing remain off. No introductory offer was added.

The required review screenshot is `marketing/app-store/subscription-review/footing-premium-monthly-review.png`: the real membership view rendered with a local StoreKit product and fictional account state. It shows monthly price, renewal terms, Restore purchases and policy links. The preview intentionally disables actions; that limitation is disclosed in the review notes. This image is for Apple's purchase review, separate from the public product-page screenshots.

Review notes cover navigation, included features and monthly allowances, Apple billing/cancellation, the separate no-billing founding grant, independent AI consent, the wellness boundary and prior sandbox results. Expiration acceptance was completed November 16: user confirmed both AI paywalls and retained free tracking/search/records; backend Apple status is 2 (expired), expires_at `2026-11-16T20:39:14Z`, with no premium/subscription entitlement or founding grant. App and subscription review notes were updated and verified after reload. The screenshot and notes were saved in App Store Connect; no Add for Review or Submit action was taken.

## Before review submission

- Build 330 finished processing, is assigned to Early Access, and is selected for App Store version 1.3.9. Selection and manual release persisted after reload.
- Expiration acceptance passed on-device and on the backend November 16.
- Reviewer credentials verified through authenticated sign-in. Added the Marcus reviewer account alongside Jordan to the prelaunch sandbox allowlist; authenticated membership status returns HTTP 200, enforced=true, no premium grant and no founding offer. This exposes the purchase flow without consuming a founding place. A physical reviewer-device purchase remains untested.
- Production notification URL is saved and persisted; fresh sandbox TEST succeeds. Premium enforcement/founding activation and rollback are staged in `docs/membership-launch-2026-11-15.md`. Production TEST remains pre-release HTTP 401 and must be repeated after first release. Public enforcement/campaign remain off.
- Submit the first subscription and app version together after final readiness approval; retain manual release.

Apple accepted the upload on November 15 at 2:35:18 PM Pacific. Processing completed, Early Access assignment was confirmed, and App Store version 1.3.9 now retains build 330 after reload. No App Review submission or public release has occurred. Jordan’s sandbox entitlement expired November 16 at 12:39:14 PM Pacific; expiration acceptance passed. Build 334 is being prepared from committed password-reset fixes to replace this candidate at the owner’s request.
