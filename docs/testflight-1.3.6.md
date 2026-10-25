# Footing 1.3.6 — TestFlight

Previous verified App Store Connect build: 1.3.5 (300). App and widget advance to 1.3.6. This release commit is expected to produce build 302 under the repository's git-commit-count numbering; commit 301 is an existing marketing case-study update.

## Included

- Compact keyboard-focused food search, visible usual-meal bookmark and Today check-in saved status.
- Make today easier task chooser and focused example-led pages.
- Optional Health-connected experiments, qualified shot-cycle observations, weekly movement/sleep/energy reflections and compact summary cards on Pulse.
- Shared experiment access from Pulse, Make today easier and Personal experiments. Source/coverage details are collapsed beneath the visual summaries.
- Today's fit feedback, an explicitly approved easier-day memory recipe and quiet experiment reflection/versioning.
- Gentler-day support, familiar-food recovery actions and deliberate water-size selection.
- Footing-styled memory review with editable exact wording, approval gating and an accurate save confirmation.

## Validation and phone checks

Final simulator validation: 519 unit tests executed (512 passed, seven optional live checks skipped), and all 12 native UI tests passed. Results are recorded with the release artifacts. Earlier focused checks cover account-switch races, local-store isolation, memory approval, optional legacy data, cycle eligibility, missing data, experiment version separation, search keyboard space and navigation at large text sizes.

Real Apple Health permission/read behavior and Watch ingestion still need physical-iPhone acceptance. The TestFlight notes include these checks along with account switching, onboarding, offline notes, Siri, usual meals and skipped-shot undo. No new backend migration or Edge Function deployment is required by this release. Existing App Store submission-readiness items remain separate.

Archive/export/signature checks, exact source commit, test counts, upload result, App Store Connect build ID and tester-group status will be captured in `build/TestFlight-1.3.6-302/release-verification.json`. This source document does not itself claim processing or distribution has completed.
