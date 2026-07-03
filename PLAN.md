# NutriPulse — Architecture Plan (DRAFT, pending confirmation)

Native iOS rebuild of NutriPulse, a personal nutrition & health tracking app.
Migration from a Base44 prototype. Owner is an experienced PM/web dev
(React/TS/Supabase) new to Swift — explain Swift/SwiftUI concepts along the way.

> Status: **core decisions confirmed** (see Locked decisions). A few product
> details remain open at the bottom — resolve them in the build session.

## Tech stack
- Swift + SwiftUI, iOS 17+ (no storyboards)
- Supabase (Swift SDK) — Postgres, Auth, Edge Functions, Storage
- HealthKit — bidirectional weight & water; read active energy, workouts, HRV, resting HR, sleep
- Claude API — AI Nutrition Coach (proxied via Supabase Edge Function; key never ships in the app)
- FatSecret API — food search + barcode lookup (proxied via Edge Function)

## Why MVVM here + the Swift concepts behind it
- **View** = a SwiftUI `struct` that describes UI declaratively (like a React
  function component returning JSX). Re-renders when observed state changes.
- **ViewModel** = an `@Observable` class (iOS 17's Observation framework — the
  modern replacement for `ObservableObject`/`@Published`). Holds screen state +
  logic, calls services. Views hold their VM with `@State`.
- **Service/Repository layer** = plain classes (SupabaseRepository,
  HealthKitManager, CoachService) that do I/O. ViewModels never touch the
  network directly — same separation you'd use with hooks + an API client in React.
- **Models** = `Codable` structs mirroring DB rows (like TS types/interfaces).

## Proposed folder structure
```
NutriPulse/                     # Xcode project root
├── NutriPulseApp.swift         # @main entry point
├── App/
│   ├── AppState.swift          # global session/auth state (@Observable)
│   └── RootView.swift          # routes: auth flow vs main tab bar
├── Core/
│   ├── Supabase/               # shared client + repositories
│   ├── HealthKit/              # HealthKitManager
│   ├── AI/                     # CoachService (-> Edge Function)
│   ├── Networking/             # FatSecret client (-> Edge Function)
│   └── Extensions/
├── Models/                     # Codable structs: UserProfile, FoodLog,
│                               #   FoodItem, DailyGoal, WeightLog, WaterLog, GLP1Log
├── Features/
│   ├── Auth/                   # AuthView + AuthViewModel (email/pw + Apple)
│   ├── Onboarding/             # goal-calculation flow
│   ├── Today/                  # FIRST BUILD: rings, meal list, date nav
│   ├── FoodLogging/            # search, barcode, manual entry, favorites
│   ├── Goals/
│   ├── Analytics/             # 7/14/30-day trend charts (Swift Charts)
│   └── Coach/                  # AI chat
├── DesignSystem/               # Theme (colors, type), reusable components
└── Resources/                  # Assets.xcassets
```

## Supabase schema (proposed)
RLS on every table (`user_id = auth.uid()`), mirroring the Supabase pattern the
owner already uses. `food_items` may hold shared rows (`user_id IS NULL`) readable
by all.

- **profiles** (1:1 with `auth.users`): id, email, full_name, dob, sex,
  height_cm, activity_level, dietary_prefs, created_at
- **daily_goals**: id, user_id, effective_date, calories, protein_g, carbs_g,
  fat_g, fiber_g, water_ml_target — dated rows so goals can change over time
- **food_items** (catalog/cache): id, user_id?, source (fatsecret|manual),
  external_id, name, brand, serving_desc, serving_grams, + per-serving macros
- **food_logs**: id, user_id, logged_at, log_date, meal (breakfast|lunch|dinner|snack),
  food_item_id, quantity, **denormalized macro snapshot** (so editing a food
  definition later doesn't rewrite history), created_at
- **favorites**: id, user_id, food_item_id
- **weight_logs**: id, user_id, logged_at, weight_kg, source (manual|healthkit)
- **water_logs**: id, user_id, logged_at, log_date, amount_ml, source
- **glp1_logs**: id, user_id, injected_at, medication, dose_mg, site, next_due_at

## Secrets & proxy pattern (important)
An iOS app binary can be inspected — **no API keys in the app.** Claude and
FatSecret calls go through **Supabase Edge Functions** that hold the secrets,
exactly like the owner's other project. The app calls the Edge Function with the
user's Supabase auth token.

## First build target: Today view
1. Date navigator (prev/next day, "Today")
2. Macro progress rings (Swift Charts / custom) — **which 4?** (calories,
   protein, carbs, fiber listed; fat tracked but not ringed — confirm)
3. Food log list grouped by meal, with per-item + per-meal totals
4. Pulls from `food_logs` + `daily_goals` for the selected date

## Locked decisions (confirmed)
1. **Offline persistence: YES.** SwiftData as local cache + Supabase as source of
   truth. Logging works offline; sync in the background. (Biggest architectural fork — settled.)
2. **Apple Developer account: YES** (paid). Sign in with Apple, HealthKit on
   device, and on-device barcode scanning are all available — configure the
   entitlements/capabilities accordingly.
3. **Xcode project generation: XcodeGen.** Text `project.yml` generates the
   `.xcodeproj`; new Swift files auto-included; project is git-diffable. First
   build step: `brew install xcodegen`, author `project.yml`, run `xcodegen`.
   Do NOT hand-edit the `.xcodeproj` — edit `project.yml` and regenerate.

## Still open (resolve in the build session)
- **New Supabase project** for NutriPulse (separate from existing work)? Assumed yes.
- **Confirm the 4 macro rings** — calories, protein, carbs, fiber assumed; does
  fat get a ring or is it tracked without one?
- **Denormalized macro snapshot on food_logs** — recommended; confirm.
- **Onboarding goal math** — Mifflin-St Jeor BMR + activity multiplier, or the
  specific formula from the Base44 version?
