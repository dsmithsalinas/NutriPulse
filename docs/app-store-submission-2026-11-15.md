# Footing submission preparation — November 15, 2026

## Saved in App Store Connect

- App name retained: **Footing: GLP-1 Nutrition**.
- Subtitle: **Protein, meals & daily habits**.
- Version changed from 1.0 to **1.3.9**; final candidate **build 334** selected and verified after reload. It adds committed password-reset fixes to the privacy/membership candidate.
- Description, promotional text, keywords, support/marketing URLs and copyright entered.
- Reviewer notes rewritten for current navigation, optional permissions, independent AI consent, free/premium features, monthly allowances, founding access and account deletion. Existing review credentials/contact retained; reviewer sign-in and authenticated membership status verified.
- **Manual release** selected. Nothing submitted to App Review or released.
- Free app-download pricing configured; app availability **United States only**, matching the current subscription territory. Price comparables for other territories do not enable those territories.
- **18+** age rating saved, with the adult terms URL. Questionnaire: age assurance enabled (adult DOB gate); no parental controls, unrestricted web browser, broadly distributed UGC, social feed, user-to-user messaging or advertising; regular prescription-medication references and wellness guidance; no profanity, horror, sexual, violent, gambling, contest or loot-box content.
- Declared **not a regulated medical device**, consistent with Footing's intended nutrition/wellness and record-keeping functionality and its prohibition on diagnosis/treatment/dosing guidance. This declaration is not regulatory approval.
- Privacy policy URL: https://tryfooting.app/privacy
- Privacy choices URL: https://tryfooting.app/privacy#s7

## App Privacy answers

All categories: **not used for tracking**. No advertising purposes selected.

| Data type | Linked to user | Purposes | Evidence |
| --- | --- | --- | --- |
| Name | Yes | Functionality, personalization | Profile; name in Pulse context |
| Email | Yes | Functionality | Supabase/Apple authentication |
| Health | Yes | Functionality, personalization | Nutrition, body, medications, Health context |
| Fitness | Yes | Functionality, personalization | Workout/activity records and coaching context |
| Sensitive info | Yes | Functionality, personalization | Optional halal/kosher dietary requirements and explicit free-text context; no inferred beliefs |
| Customer support | Yes | Functionality | Account-linked feedback and app-version context |
| Other user content | Yes | Functionality, personalization | Chat, notes, approved memories and goals |
| User ID | Yes | Functionality | Account ownership/access controls |
| Device ID | No | Analytics | Bundled TelemetryDeck SDK privacy manifest; no Footing account identifier configured in SDK |
| Purchase history | Yes | Functionality | Apple transactions, subscription and founding-access records |
| Product interaction | Yes | Functionality, analytics | Account-linked AI allowance counters plus pseudonymous usage signals; whole category conservatively linked |
| Crash data | No | Functionality, analytics | Content-free previous-session-crash signal |
| Other diagnostics | No | Functionality, analytics | Content-free sync/fallback signals |
| Other data types | Yes | Functionality, personalization | DOB, sex, preferences, consent/settings |

Payment-card/bank details are processed by Apple, not received by Footing. Audio is not retained by Footing; speech becomes text. Scanner camera images are not uploaded. No contacts, browsing history, photos, location, ad data or stored search-history collection was established in this inventory. Live infrastructure may retain technical request logs; never add request bodies or personal content to logs.

The 14 categories were **published November 15, 2026**, after the owner explicitly approved Apple's final accuracy, legal-compliance and update agreement. App Store Connect displayed ‘Published a few seconds ago by Dustin Smith-Salinas’. No tracking or advertising purposes are declared.

## Privacy source corrections

- Published privacy policy includes Apple membership verification, founding claims, AI allowance counters, deletion and the fact that deleting Footing does not cancel Apple billing. Membership terms are published as well.
- Added clear pseudonymous device analytics/diagnostics wording and optional sensitive preferences.
- Native manifest now includes sensitive info and other diagnostics; name includes personalization; product interaction covers linked membership counters as well as analytics. Device ID is already declared by the bundled SDK.
- Build 330 contains the corrected manifest and replaces 326 for submission. Signed Release archive, distribution IPA/privacy checks and all three membership UI checks passed. See `docs/testflight-1.3.9-330.md`.

## Deployment and validation evidence

Source commit `6576bd8` was pushed before the site deployment. Cloudflare Worker `footing-site` version `93d3412a-4ffd-4778-b55a-aa3d822d1cd0` uploaded exactly two changed assets: privacy.html and terms.html. Both public routes return success and their bytes match committed source. The site production build and native plist validation passed. The capture checks passed on both native iPhone sizes. Both six-image sequences persisted in App Store Connect after reload. No genuine Duo capture is claimed. The owner subsequently approved privacy publication; Apple's Publish agreement was accepted and publication confirmed. The owner also confirmed FatSecret commercial distribution is covered. Content Rights is saved as ‘Yes, this app has the necessary rights to its third-party content’ and persisted after reload. This records owner-provided licensing confirmation, not an independent contract audit.

## Remaining owner/dependency items

- Six actual-app screenshots are uploaded for both medium (1206 × 2622) and large (1320 × 2868) iPhone displays, in order: Today, AI meal review, Pulse, Progress, shot routine, food detail. Capture checks passed on both simulator sizes; all PNGs are opaque RGB. Owner can review/replace this draft set before submission. See `marketing/app-store/2026-11-15/README.md`. Genuine Duo captures remain blocked by available simulator runtime support.
- Reviewer credentials are verified. Marcus and Jordan are the only prelaunch sandbox-allowlisted accounts; Marcus receives the purchase flow with no premium grant or founding claim.
- Subscription metadata, required review screenshot and detailed notes are saved. Notes disclose the read-only local StoreKit capture and completed expiration test; updated app/subscription notes persisted after reload. Submit the first subscription alongside the app version.
- Cancellation/expiration acceptance passed November 16: Apple status 2, no premium/subscription entitlement; user confirmed AI paywalls and retained free functionality.
- Production notification URL is now configured and persisted. Activation/rollback steps are prepared in `docs/membership-launch-2026-11-15.md`; global enforcement and founding claims remain off. Fresh sandbox TEST succeeds; production API delivery remains unverified until after first release (current request returns HTTP 401).
- Owner selected iPhone-only release November 16. Mac and Vision Pro availability are disabled and persisted. Replacement build 334 contains committed password-reset fixes and is selected. Apple shows the app, subscription group and monthly product as **Items Ready to Submit (3)** with Submit for Review enabled; final submission was not performed. See `docs/testflight-1.3.9-334.md` for checks and the remaining live password-reset smoke test.

## Primary references

- [Apple App Privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- [Screenshot specifications, including iPhone Duo](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Age rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)
- [Medical-device declaration](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status)

## Submitted November 16, 2026

Owner confirmed password reset on build 334 and explicitly authorized submission. Manual release was verified selected. Apple confirmed **3 Items Submitted** (iOS 1.3.9 build 334, Footing premium group, monthly subscription) and **Waiting for Review**. Submission `b9130730-db70-4843-8bc6-af435cf12e3d`. No public release or membership launch activation occurred.
