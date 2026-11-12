# Footing 1.3.8 (308)

November 12, 2026. Follow-up to uploaded build 306.

## Changes

- Today pairs protein and calories/macros without the empty space below protein. Shot-cycle context uses a compact full-width strip.
- Medications display each medicine once, with separate morning/evening status and log menus. Taken, skip, undo and history remain available.
- Practical support actions move from Today to a compact expandable section in Pulse. Active lighter-tracking status stays on Today, with controls in Profile.
- Non-AI tools require no AI consent. Explicit AI requests still require consent. Profile provides a fallback when Pulse is disabled.

## Verification

Compact Today/medication changes: 25 checks passed. Pulse support changes: 19 distinct checks passed, including portrait, expanded layout, consent gates and Pulse-off access. Simulator screenshots and fixture details are documented in `today-compact-medications.md` and `pulse-support-tools.md`. No real health data or AI requests were created by these UI checks.

User authorized source push and new Apple/TestFlight build. Archive, signature, export and upload outcomes will be recorded in `build/TestFlight-1.3.8-308/release-verification.json`. Physical-device Health and Duo acceptance remains as documented for build 306.
