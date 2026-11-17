# Footing premium subscription review image

`footing-premium-monthly-review.png` is an opaque 1206 × 2622 PNG captured from the production membership view using a local StoreKit product and fictional account state on iOS 27.2. No real account, purchase receipt, Apple key or health data is shown.

It shows $2.99/month, automatic-renewal/cancellation terms, the distinct founding grant, Restore purchases and links to privacy/terms. Buttons are intentionally disabled in the read-only preview; App Store Connect review notes disclose that. This is a purchase-review attachment, not an Apple payment-sheet screenshot or a claim of a live transaction.

Source capture: `MembershipUITests.testLocalStoreKitPriceAndPurchaseTerms`, `build/SubscriptionReview-330.xcresult`. The other two membership UI checks also passed. Runtime: iOS 27.2, iPhone 18 Pro simulator.

Product: `com.dustin.nutripulse.premium.monthly`; subscription Apple ID `6834984644`; group `22580786`. Existing English (US) display name: Footing premium. Description: Pulse coaching, AI food logging, and weekly guidance.

Saved review notes explain Profile → Your membership, monthly allowances, Apple billing and cancellation, the independent no-billing founding offer, AI consent, free features and wellness boundaries. They record purchase/reopen/restore/cancellation and expiration testing as completed. Expiration was confirmed November 16 on-device (AI paywalls, retained free tracking/search/records) and on the backend (Apple status 2 and no effective premium entitlement). Updated notes persisted in App Store Connect.
