# Footing for Android: build blueprint

Status: exploration blueprint
Scope: a separate, native Android app that shares Footing's accounts and backend with iOS
Recommendation: build Android in a new repository; do not convert or reorganize the current iOS project

## The short version

Footing should become two native apps connected to one shared service:

| Product surface | Technology | Where it lives |
| --- | --- | --- |
| Footing for iPhone | Swift + SwiftUI + SwiftData | Current `NutriPulse` repository |
| Footing for Android | Kotlin + Jetpack Compose + Room | New `footing-android` repository |
| Shared accounts, user data, food services, and Pulse | Supabase database, Auth, and Edge Functions | Existing Supabase project |

This keeps the iOS build independent. No Swift code has to be moved into the Android project, and Android work does not have to wait for an iOS release.

The shared backend is the contract between the two apps:

```text
                    ┌──────────────────────┐
                    │  Footing Supabase    │
                    │                      │
                    │  Auth + database     │
                    │  food functions      │
                    │  Pulse coach         │
                    └──────────┬───────────┘
                               │
                   same account and data
                    ┌──────────┴──────────┐
                    │                     │
           ┌────────▼────────┐   ┌────────▼────────┐
           │ Footing for iOS │   │ Footing Android│
           │ Swift / SwiftUI │   │ Kotlin / Compose│
           │ SwiftData       │   │ Room            │
           │ Apple Health    │   │ Health Connect  │
           └─────────────────┘   └─────────────────┘
```

## What exists today

The current iOS app is a substantial native application, not a simple collection of screens. It contains roughly 17,000 lines of Swift, more than 100 unit tests, four main tabs, a local-first sync system, and several Apple-specific integrations.

The Android plan needs to recreate these product capabilities:

- Account creation, sign-in, password recovery, onboarding, and account deletion
- Today screen with nutrition rings, meals, water, movement, health signals, dose status, and supportive nudges
- Food logging by voice, manual entry, search, favorites, and barcode
- Offline-safe food, water, workout, and goal storage with later synchronization
- Analytics for nutrition, weight, body composition, movement, and GLP-1 history
- Pulse chat, automatic check-ins, weekly summaries, history, suggestions, and contextual coaching
- Profile, units, goals, measurements, body history, feedback, legal links, and data controls
- GLP-1 dose logging, injection ritual, history, and discreet reminders
- Health data import/export
- Protein-floor home-screen widget
- Privacy-safe telemetry and crash visibility

## Recommended Android foundation

Use a normal native Android stack:

| iOS implementation | Android equivalent | Why |
| --- | --- | --- |
| SwiftUI | Kotlin + Jetpack Compose | Google's modern native UI system |
| SwiftData | Room database | Reliable structured local storage with tested migrations |
| `@Observable` view models | Android ViewModel + StateFlow | Keeps screen state separate from the UI |
| Swift concurrency | Kotlin coroutines + Flow | Handles network and database work without freezing the app |
| Supabase Swift | Supabase Kotlin | Uses the existing Supabase project and row-level security |
| SyncEngine + network monitor | Repositories + Room outbox + WorkManager | Preserves local-first behavior and retries work reliably |
| HealthKit | Health Connect | Android's user-controlled health-data layer |
| WidgetKit | Jetpack Glance | Android home-screen widget |
| AVFoundation barcode scanner | Google Code Scanner initially; CameraX + ML Kit if a custom scanner is needed | The initial option avoids a camera permission and is simpler |
| Apple Speech | Android SpeechRecognizer | Supports voice-to-text, with device-dependent availability |
| Apple local notifications | Android notifications + scheduled background work | Supports discreet dose reminders |
| TelemetryDeck Swift SDK | TelemetryDeck Kotlin SDK | Keeps the current privacy-safe event approach |

Recommended minimum device: Android 9 (API 28). This keeps the supported range broad while matching Health Connect's practical availability. The app should compile against and target the current stable Android requirements when implementation begins.

## Proposed Android project shape

Start with one Android application module and clear internal boundaries. Multiple Gradle modules can be introduced later if the project earns that complexity.

```text
footing-android/
├── app/
│   ├── ui/                 Compose screens, navigation, and Footing theme
│   ├── feature/
│   │   ├── auth/
│   │   ├── onboarding/
│   │   ├── today/
│   │   ├── foodlog/
│   │   ├── analytics/
│   │   ├── pulse/
│   │   ├── body/
│   │   ├── glp1/
│   │   └── profile/
│   ├── domain/             Goal, ring, nudge, units, and coaching rules
│   ├── data/
│   │   ├── local/          Room entities and data-access objects
│   │   ├── remote/         Supabase and Edge Function clients
│   │   ├── repository/     One source of truth for each type of data
│   │   └── sync/           Outbox, conflict rules, and WorkManager jobs
│   ├── platform/
│   │   ├── health/         Health Connect
│   │   ├── barcode/
│   │   ├── speech/
│   │   ├── notifications/
│   │   ├── telemetry/
│   │   └── widget/
│   └── test/
├── docs/
│   ├── backend-contract.md
│   ├── feature-parity.md
│   └── release-checklist.md
└── .github/workflows/       Build, test, and signed internal-release checks
```

## Workstream 1: define the shared contract

This is the most important preparation work. The Android app should use the same account and data as iOS without making the iOS app fragile.

### Backend changes

- Document every table, RPC, Edge Function request, response, enum, unit, and date rule the mobile apps rely on.
- Preserve the current Supabase row-level security rules so each user can only access their own data.
- Add contract tests for:
  - food search, food detail, barcode lookup, and talk-to-log
  - Pulse requests and responses
  - account deletion
  - profiles, goals, logs, favorites, analytics, and feedback
- Add a staging Supabase environment or isolated test users so Android development cannot damage production data.
- Treat server changes as backward-compatible migrations: the currently released iOS build must continue working before, during, and after every Android change.

### Health-source migration

Several database tables currently accept only `manual` or `healthkit` as the source. Workout and body-measurement deduplication also uses a column named `healthkit_uuid`.

Before Health Connect sync ships:

1. Expand the accepted source values to include `health_connect`.
2. Add a vendor-neutral external record identifier, such as `external_record_id`.
3. Uniquely identify imported records by user, source, and external record ID.
4. Backfill or continue reading the old HealthKit-specific identifiers.
5. Keep the old columns until every released iOS version is known to work with the new contract.

This avoids pretending Android health data came from Apple Health and prevents the same workout from being imported twice.

### Date, unit, and enum rules

Port these as explicit contracts, not visual guesses:

- `log_date` is the user's local calendar day, not UTC.
- Stored body weight is kilograms and stored body measurements are centimeters.
- Food nutrient snapshots and quantities must calculate exactly as they do on iOS.
- Meal names, activity slugs, measurement-site values, coach message types, and GLP-1 values must remain API-compatible.
- Unknown future enum values must not crash either app.

## Workstream 2: accounts and cross-platform identity

Android should connect to the existing Supabase Auth project so users see the same Footing account and data on either phone.

Build:

- Email/password sign-up and sign-in
- Email verification behavior matching iOS
- Password reset with an Android App Link/deep link
- Session restoration and sign-out
- Profile loading and onboarding state
- Account deletion through the existing server function

### Sign in with Apple is a product decision, not an iOS-only detail

Some existing users may have created their Footing account using Apple. They still need a route into the same account on Android.

Recommended launch behavior:

- Offer **Sign in with Apple** on Android through Apple's browser-based OAuth flow.
- Add and verify the Android callback URL in Supabase Auth.
- Test private-relay Apple addresses and returning-user identity matching.
- Set an operational reminder or automation for Apple's OAuth client-secret rotation; the browser-based Apple flow requires a new secret every six months.

Google sign-in can also be added, but it should not silently create a second account for an existing Footing user. Design and test identity linking before presenting it as an option.

## Workstream 3: local-first data and synchronization

This is more than “connect the screens to Supabase.” The iOS app writes important actions locally first so a weak connection does not lose a food log.

The Android version should preserve that behavior:

1. The user logs or edits something.
2. Room saves it immediately on the phone.
3. The UI reads the Room record and responds immediately.
4. A sync outbox marks the create, update, or deletion as pending.
5. The repository sends it to Supabase when a connection is available.
6. Completion uses a revision check so a slow request cannot overwrite a newer edit.
7. Pulling remote data must not replace unsynced local changes.
8. Deletions use tombstones until the server confirms them.
9. WorkManager retries required work after the app closes or the phone restarts.

Android UI must use the same honest states already established on iOS:

- “Saved on this phone” when a change is local only
- “Saving your changes” while a push is active
- “Couldn't refresh” when a pull fails
- Never claim a successful sync after one stage failed

The first Room tables should cover food logs, water logs, workout logs, and daily goals because those are the current iOS offline path. Other data can remain network-backed initially and move local only when the product needs it.

## Workstream 4: screen and feature implementation

Build by complete user journeys, not by creating every empty screen first.

| Journey | Android work | Backend reused? |
| --- | --- | --- |
| Start using Footing | Splash, auth, password recovery, onboarding, goal calculation | Yes |
| Understand today | Date navigation, nutrition rings, meal sections, water, dose status, movement, signals, sync status | Yes |
| Log food | Manual entry, FatSecret search/detail, favorites, barcode, talk-to-log, edit, delete | Yes |
| Get coaching | Pulse history, paging, suggestions, user messages, check-ins, weekly summary, retry/degraded states | Yes |
| See progress | Nutrition, movement, weight, body composition, and GLP-1 charts across time ranges | Yes |
| Manage body data | Weight, composition, measurements, body goals, history, and insights | Yes |
| Track medication | Dose log, injection site, next due date, ritual, history, and reminders | Yes |
| Manage the account | Profile, units, targets, feedback, legal links, sign-out, chat deletion, account deletion | Yes |

### Product rules to port with tests

Rewrite these rules in Kotlin and mirror the existing iOS tests:

- Goal and macro calculation
- Ring-closure behavior
- Under-eating and workout-aware nudges
- Maintenance-target offers
- Unit conversions and decimal input
- Barcode normalization, including UPC-E
- Local-day parsing and time-zone boundaries
- Sleep interval merging
- Health-record import and deduplication
- Coach prompt suggestions and context construction
- Dose formatting and next-dose calculation
- Body insight thresholds
- Sync race handling and deletion pruning

The Kotlin implementation does not need to look like the Swift implementation internally, but the same inputs should produce the same user-visible answers.

## Workstream 5: Android-native integrations

### Health Connect

Map current Apple Health usage to Health Connect:

| Footing data | Direction |
| --- | --- |
| Weight, body fat, BMI, lean body mass | Read and write where Health Connect supports it |
| Water | Read and write |
| Active calories, resting heart rate, HRV, sleep, steps | Read |
| Workouts and distance | Read |
| Waist circumference | Confirm current Health Connect record support; otherwise keep manual-only |

Required work:

- Explain why each permission improves Footing before opening the system permission screen.
- Request only the data types used by a visible current feature.
- Handle unavailable Health Connect, denied access, partial access, and empty data without claiming “connected.”
- Import with stable external IDs and prevent duplicate server rows.
- Keep manual entry useful when health access is unavailable.
- Update Pulse context so it describes Android health data accurately rather than calling it HealthKit.

Do not build on the legacy Google Fit API. Its APIs reach end of support in 2026; Health Connect is the appropriate mobile-first path.

### Barcode scanning

For the first Android beta, use Google Code Scanner. It supplies a system scanner without Footing requesting camera permission. Preserve Footing's existing barcode normalization and FatSecret lookup.

Move to CameraX + ML Kit only if testing shows that Footing needs its own branded viewfinder or tighter continuous-scanning control.

### Voice logging

- Use Android's speech-recognition service and pass the transcript to the existing `parse-food` function.
- Check whether on-device recognition is available.
- Explain when audio may be handled by a device's recognition provider.
- Preserve editable confirmation rows before saving food.
- Always provide manual and typed alternatives.

### Reminders

- Create a notification channel specifically for discreet dose reminders.
- Ask for notification permission in context, near the reminder feature.
- Schedule day-before, day-of, and bounded follow-up reminders.
- Cancel and replace old reminders as soon as a dose is logged.
- Test time-zone changes, daylight saving changes, device restart, and battery restrictions.
- Avoid requesting exact-alarm access unless product testing proves minute-perfect delivery is necessary.

### Widget

Recreate the protein-floor widget with Jetpack Glance after the main logging and sync flow is stable. Store a small, sanitized widget snapshot locally; do not let a widget make independent health or Supabase decisions.

## Workstream 6: design adaptation

The goal is the same Footing, not an iPhone screenshot forced onto Android.

Keep:

- Footing colors, typography character, iconography, ring language, Pulse voice, and non-shaming copy
- The four primary destinations: Today, Progress, Pulse, and Profile
- The central food-log action
- The current privacy and trust language

Adapt:

- Android back behavior and predictive back
- Material touch targets, sheets, dialogs, pickers, and permission patterns
- Keyboard handling and system insets
- Light/dark system bars
- Small phones, tall phones, foldables, and tablet-sized windows
- TalkBack screen-reader labels, font scaling, contrast, and reduced motion

Start phone-first, but make layouts responsive enough that Play's tablet and foldable testing does not expose broken screens.

## Workstream 7: quality, privacy, and release

### Automated checks

- Kotlin unit tests for every ported product rule
- Room query and migration tests
- Sync race, retry, offline, and conflict tests
- Supabase contract tests against staging
- Compose navigation and accessibility tests
- Screenshot tests for high-value Footing states
- A clean Android App Bundle build on every protected-branch change

### Device testing

At minimum:

- A current Pixel
- A current Samsung device
- Android 9, a mid-range supported version, Android 14, and the current Android release
- A small phone and a large/foldable window
- Fresh install, upgrade, poor network, no network, denied permissions, partial Health Connect permissions, and process death

Test real playback and interaction for animations, speech, scanning, notifications, and Health Connect. Emulator-only approval is not enough for those paths.

### Play Console and policy work

- Finish developer and device verification before the release path depends on it.
- Reserve the package name early, for example `com.dustin.footing` or `com.dustin.nutripulse.android`.
- Enroll in Play App Signing and protect the upload key.
- Build and upload Android App Bundles, not a production APK workflow.
- Start with internal testing, then closed testing, then production.
- Complete the Health apps declaration.
- Complete the Data safety form for every library and data path.
- Publish an Android-aware privacy policy inside the app and on the store listing.
- Include the appropriate health/medical disclaimer and avoid treatment or outcome claims.
- Provide store listing copy, phone screenshots, feature graphic, app icon, content rating, support contact, and account-deletion instructions.
- Use Play's pre-launch reports for stability, compatibility, performance, accessibility, and security findings.

## Phased delivery plan

These estimates assume one experienced Android engineer working full-time, with part-time product/design review and real-device QA. They are planning ranges, not promises.

### Phase 0 — contract and proof sprint: 1–2 weeks

Deliver:

- New, separate Android repository and basic continuous integration
- Footing theme and one branded Compose screen
- Supabase staging/test connection
- Existing-account sign-in proof, including Apple OAuth proof
- Read-only Today data for a test user
- Health Connect availability and record-type spike
- Signed App Bundle installed through Play internal testing
- Written backend contract and first parity checklist

Exit gate: one Android build can sign in, load real test data safely, and install through Play without modifying the iOS build.

### Phase 1 — app foundation: 2–3 weeks

Deliver:

- Navigation and application architecture
- Email auth, Apple auth, password recovery, session restoration, and account deletion
- Onboarding and goal calculation
- Room database, repository pattern, and first migration test
- Telemetry, crash visibility, and environment configuration

Exit gate: a new or returning user can reach a correctly personalized shell with a recoverable account.

### Phase 2 — Today, food logging, and offline sync: 4–6 weeks

Deliver:

- Today screen and date navigation
- Manual, search, favorite, barcode, and voice logging
- Water and workout logging
- Local-first outbox, edits, deletes, retries, pull reconciliation, and visible sync states
- Ported product-rule and sync tests

Exit gate: the core daily loop works through airplane mode, reconnect, process death, and a second-device edit without losing or duplicating data.

### Phase 3 — Pulse, progress, body, medication, and profile: 4–5 weeks

Deliver:

- Pulse and its context, history, suggestions, check-ins, and summaries
- Analytics charts
- Body hub, measurements, goals, and insights
- GLP-1 tracker, ritual, history, and reminders
- Full profile, feedback, legal, unit, and data-control surfaces

Exit gate: every major iOS journey has an Android implementation or an explicitly approved deferral.

### Phase 4 — Health Connect and Android polish: 3–4 weeks

Deliver:

- Health Connect read/write path and deduplication
- Permission and unavailable/partial-access states
- Android-responsive layouts and accessibility pass
- Protein-floor widget
- Notification, time-zone, speech, barcode, and process-lifecycle hardening

Exit gate: native integrations work on real Pixel and Samsung devices and never overstate their state.

### Phase 5 — closed beta and launch hardening: 3–4 weeks

Deliver:

- Internal and closed testing cohorts
- Device-matrix regression pass
- Play pre-launch report remediation
- Privacy policy, Data safety, Health apps declaration, store listing, and support path
- Performance, accessibility, release-signing, rollback, and production-monitoring checks

Exit gate: the build is closure-verified from Play install through core daily use, not merely uploaded.

### Overall range

- Lean Android beta: approximately **10–14 weeks** if Health Connect, the widget, some advanced charts/body insights, and voice logging are deliberately deferred.
- Responsible feature parity: approximately **17–24 weeks**.
- Add contingency if the current backend contract exposes drift, Apple cross-platform identity needs account-recovery work, or Health Connect lacks a clean equivalent for an iOS record type.

Trying to share the UI code now through Flutter, React Native, or Kotlin Multiplatform would be a separate migration project. It would not remove the need to rebuild and test Health Connect, notifications, scanning, speech, background sync, widgets, or Play release work. For Footing's current state, a separate native Android app is the clearer path.

## Recommended beta scope

The first Android beta should prove Footing's daily value, not chase every iOS edge feature.

Include:

- Same Footing account and data
- Auth, recovery, onboarding, and account deletion
- Today screen
- Manual, search, favorite, and barcode food logging
- Water, workout, and GLP-1 logging
- Reliable local-first sync
- Pulse
- Essential Profile and goal editing
- Discreet dose reminders
- Privacy-safe telemetry and feedback

Consider deferring until after the core beta is stable:

- Health Connect
- Protein widget
- Voice logging
- Full body hub and every analytics chart
- Google sign-in and identity linking
- Tablet-specific layouts beyond safe responsiveness

Do not defer:

- Existing-account compatibility
- Offline data safety
- Password recovery
- Account deletion
- Privacy, health disclosures, and accurate state messaging
- Real-device testing

## Decisions to make before full implementation

1. Is the first public Android release a lean beta or full iOS parity?
2. Must current Apple-sign-in users access Android on day one? Recommended answer: yes.
3. Is Android 9 an acceptable minimum? Recommended answer: yes.
4. Should Android launch Health Connect in beta one or add it after daily logging is stable? Recommended answer: after the core loop unless beta recruitment specifically depends on it.
5. Does the initial Android package keep the internal NutriPulse identity for continuity, or use a new Footing-specific package? The package is permanent once published, so decide it before the first Play artifact.
6. Who owns shared Supabase migrations and Edge Function releases once two mobile apps depend on them?

## Recommended first commitment

Approve only Phase 0 first.

It is a small, reversible exploration that answers the expensive questions—same-account auth, backend compatibility, Health Connect fit, Android design feel, and Play installation—before committing to a multi-month parity build.

Phase 0 should not alter the iOS project structure, publish a production Android app, or move the backend. Its result should be a working internal Android proof plus a better estimate based on real constraints.

## Current reference links

- [Android architecture recommendations](https://developer.android.com/topic/architecture/recommendations)
- [Jetpack Compose](https://developer.android.com/develop/ui)
- [Room local database](https://developer.android.com/training/data-storage/room)
- [WorkManager](https://developer.android.com/develop/background-work/background-tasks/persistent)
- [Health Connect setup](https://developer.android.com/health-and-fitness/health-connect/get-started)
- [Google Fit migration guidance](https://developer.android.com/health-and-fitness/health-connect/migration/fit)
- [Supabase Kotlin quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/kotlin)
- [Supabase Kotlin auth and deep links](https://supabase.com/docs/reference/kotlin/initializing)
- [Supabase Sign in with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple?platform=kotlin)
- [Google Code Scanner](https://developers.google.com/ml-kit/vision/barcode-scanning/code-scanner)
- [Jetpack Glance widgets](https://developer.android.com/develop/ui/compose/glance)
- [Play App Bundle testing](https://developer.android.com/guide/app-bundle/test)
- [Google Play Health Content and Services policy](https://support.google.com/googleplay/android-developer/answer/16679511)
- [Google Play Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469)
