# Footing 1.3.5 — TestFlight

Previous verified live release: 1.3.4 (299). App and widget advance to 1.3.5; the next source commit generates build 300. Release preparation and server rollout are tracked separately from App Store submission readiness.

## What to test

- Create a fresh account: five-screen Start with what matters onboarding, Cove/current logo, optional personal focus, grouped basics, adult eligibility, optional Pulse permission, and final review.
- On final review, edit nutrition targets and your focus; optionally connect Apple Health. Start with or without saving focus. Check What Pulse knows contains only the focus you explicitly approved. Declining Pulse or skipping focus must still let you start tracking.
- Confirm daily calorie/macro goals are visible on Today, including days without food entries. Partial diaries remain unknown rather than missed goals.
- Save a whole meal using the compact bookmark-plus icon in its header. Individual food stars remain separate; the large inter-meal save buttons are removed.
- Talk to Log requests its own AI food permission, independently of Pulse. Decline and continue with search/manual/usual-food logging; re-enable or withdraw the permissions independently in Profile.
- Apple-linked deletion requests fresh Apple confirmation. Automatic token revocation remains blocked until server signing credentials are configured; the explicit manual-disconnection fallback remains available. Do not test deletion using a real account you want to keep.
- Recheck Profile, usual-meal saving, skipped-shot clear/undo, offline notes, water logging, and Siri on a physical phone.

Validation before archive: 498 unit tests executed, 491 passed and seven opt-in live checks skipped; three UI walkthroughs passed. Server contracts: 18 passed; Apple signing/verification/HTTP mock checks: four passed. Three changed Edge Functions type checked. Actual onboarding simulator captures and design QA are under marketing/onboarding-review-2026-10-20/implemented/.

Live server compatibility: the new food-consent column and strict parse-food/coach-chat checks must be rolled out with this app. Older builds cannot grant this separate food permission themselves; update to this build to grant it. The Apple-linked deletion endpoint also requires the new confirmation or explicit manual fallback. Current App Store Connect privacy declarations, legal agreement and other submission-readiness work remain separate.

Archive/signature/export/upload status will be captured in build/TestFlight-1.3.5-300/ and the App Store Connect build record. This document alone does not claim upload, processing, beta approval, or automatic Apple token revocation has succeeded.
