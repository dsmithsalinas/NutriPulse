import SwiftData
import Foundation

// Versioned-schema baseline + migration plan for the local SwiftData cache.
//
// Why this exists: `ModelContainer(for:)` with no plan relies on automatic lightweight
// migration, which can only handle a narrow set of changes (e.g. adding an *optional*
// property, or one with a schema-level default). A change it can't handle — like adding
// the non-optional `SDFoodLog.revision` — makes the store fail to open, which sent the
// container init in NutriPulseApp to its destructive fallback: it deleted the on-disk
// store and rebuilt it empty. That silently discarded the local cache, including any rows
// that hadn't synced to Supabase yet (pendingCreate), which are unrecoverable.
//
// A SchemaMigrationPlan gives SwiftData an explicit, ordered path between schema versions.
// Lightweight stages cover additive changes; custom stages let us backfill values so an
// otherwise-impossible change (new non-optional field, renamed/retyped property) migrates
// instead of throwing — keeping us off the wipe path.
//
// ─────────────────────────────────────────────────────────────────────────────
// HOW TO EVOLVE THE SCHEMA (do this for every @Model change — add/remove/rename a
// property, change a type, change a uniqueness constraint):
//
//   1. Add a new `NutriPulseSchemaVN` enum below whose `models` reflect the NEW shape.
//      If a model's fields differ from the previous version, define that version's shape
//      in its own namespace (a nested typealias or a copied @Model) so each VersionedSchema
//      describes exactly what was on disk at that version.
//   2. Append the new schema to `NutriPulseMigrationPlan.schemas` (in order).
//   3. Append a `MigrationStage` from the previous version to the new one in `stages`:
//        • `.lightweight(...)` for purely additive/optional changes.
//        • `.custom(...)` when you must backfill or transform data (this is the tool that
//          would have made the `revision` addition safe).
//   4. Point `Schema(versionedSchema:)` in NutriPulseApp at the newest version.
//
// The baseline below (V1) is the schema as it stands today. We start versioning from here;
// stores already on this shape open with no migration.
// ─────────────────────────────────────────────────────────────────────────────

enum NutriPulseSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SDFoodLog.self, SDWaterLog.self, SDDailyGoal.self]
    }
}

// The newest versioned schema. Referenced by NutriPulseApp when building the container;
// bump this alias when you add a V2 so there's a single place that names "latest".
typealias NutriPulseSchemaLatest = NutriPulseSchemaV1

enum NutriPulseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NutriPulseSchemaV1.self]
    }

    // No stages yet — V1 is the baseline. Each future version adds one stage here linking
    // it to its predecessor, so SwiftData always has a migration path and never has to
    // fail-open into the destructive fallback.
    static var stages: [MigrationStage] {
        []
    }
}
