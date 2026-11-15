# Footing 1.3.9 (326): sandbox purchase check

Prepared November 15, 2026. Source commit `03e9d2b` was pushed before archiving. Apple accepted the upload at 11:17 AM Pacific on November 15. Processing completed. App Store Connect shows 1.3.9 (326), Ready to Submit, assigned to the internal Early Access group with one invitation. It is available for the owner to install through TestFlight; no external beta or public App Store review submission was made.

## Included changes

- Widget account restoration preserves data; unavailable Health data retains widget layout/actions.
- Onboarding uses selectable Daylight pills and feet/inches for imperial height, including accessible layouts.
- A tap records a medication as Taken; long-press offers Skip dose; undo/history remain available.
- Native membership screen, $2.99 monthly StoreKit purchase, account-bound server verification, unfinished-transaction retry, restore and subscription management; first-50 three-month founding flow is included but campaign stays closed.

The app and widget both report 1.3.9 (326). Archive/export signatures, shared App Group and release entitlements passed. No debugger entitlement, local StoreKit configuration or private Apple key is shipped. Exported IPA SHA-256: `31807e7a46e5194c4b0bc96ab7cc9f2369b5669f1809586badd2cdf38188b74c`.

Validation: 32 focused tests passed on iOS 26.5; its StoreKit service returned SKInternalErrorDomain 3 for two local StoreKit checks. All eight membership unit tests and the price/terms UI test passed on a fresh iOS 27 simulator, resolving those two failures. The signed Release device archive and export succeeded. Detailed evidence lives in `build/TestFlight-1.3.9-326/release-verification.json` and the result bundles under `build/`.

## App Store Connect readiness

The monthly subscription draft is now available in the United States at $2.99. It remains Prepare for Submission; no public App Store release occurred. The owner's internal Early Access group automatically receives Xcode builds. No external tester invitations were sent for this upload.

At the pre-upload check, the Paid Apps Agreement was Pending User Info: bank account and U.S. W-9 were incomplete. The owner must complete those directly. [Apple requires an Active agreement even for sandbox In-App Purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/). Notification TEST delivery is already verified; that does not establish purchase availability.

## iPhone walkthrough

1. Complete App Store Connect → Business → banking and tax information, and wait for Paid Apps Agreement to become Active.
2. Open TestFlight → Footing and install 1.3.9 (326), replacing the old build.
3. In Footing, sign in with the existing Jordan disposable account selected for this test. Its UUID is the sole server sandbox allowlist entry. This is the Footing login, separate from the Apple Account that TestFlight uses.
4. Open Profile → Your membership → Refresh membership. Expect the localized $2.99 monthly price. Founding claims are closed; no founding claim should be needed or consumed.
5. Tap Subscribe. Confirm that Apple's purchase sheet identifies the TestFlight/test environment and says there is no charge. [TestFlight purchases use sandbox and are free](https://developer.apple.com/in-app-purchase/). The initial purchase/restore check can use the Apple Account already on the TestFlight device; a dedicated Sandbox Apple Account is useful for later controlled renewal, refund and interruption scenarios.
6. Optionally cancel the first sheet to verify that nothing unlocks, then repeat and confirm the test purchase. Expect membership to show a subscription expiration and premium access.
7. Try one Pulse request or AI meal parse. Grant AI-sharing consent separately if requested; purchasing must not grant consent automatically.
8. Force-quit and reopen Footing. Confirm the same account retains premium. Open Your membership → Restore purchases and confirm access remains.
9. Tell Codex that the purchase completed (or provide the on-screen error). Backend verification should confirm environment Sandbox, the expected product, ownership matching the disposable UUID, active unrevoked status and an expiry; then test cancellation/renewal/refund behavior separately.

Do not delete/recreate the Footing account during restore testing; purchase ownership intentionally remains bound to the original account. Global premium enforcement remains off for other beta accounts and founding claims remain closed with zero places consumed.
