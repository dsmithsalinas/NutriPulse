# Today density fixes — November 12, 2026

User screenshots of 1.3.8 showed a gap beneath Protein and an oversized medication checklist for two items taken twice daily.

1. Today previously placed Protein beside a stack of Calories and Shot cycle. The custom row measured the taller stack but placed Protein with an unconstrained height, leaving an unused slot. Protein is now paired directly with calories/macros; water and movement share the next row; shot context uses a compact full-width check-in strip. Horizontal Daylight rows pass their measured height to both children, while large-text/narrow rows retain natural stacked heights.
2. Medications now groups occurrences by routine, name and amount. A twice-daily medicine shows its name/amount once with two individual time/status menus. Each menu preserves Taken, Skip, Undo and historical review. Different amounts/names during schedule changes stay in separate groups. No bulk dose logging, persistence, schedule, revision, conflict or notification semantics changed. Completed days retain a review disclosure. Manage and history remain accessible in the header, and real sync/error states still show when applicable.
3. Screenshot fixtures use an isolated temporary medication store with automatic sync/notification reconciliation disabled. They contain two fictional display examples with four independently tracked occurrences, two already taken. They never write to the user's account or submit medication data.

Validation covers equal Protein/calorie bottom edges in portrait and expanded layouts, compact medication height under 300 points at normal text, independently marking/skipping/undoing doses, and 44-point controls with the largest text. The existing 13 medication model/storage tests and nine rendering/layout tests passed. UI captures and final results are recorded alongside the screenshot gallery. No new TestFlight build or deployment is part of this layout fix.

Final verification: 25 distinct checks passed (three UI, 13 medication model/storage, nine rendering/layout). `git diff --check` passed. The five final native captures were exported and visually reviewed.

[Updated screenshot gallery](/Users/dustinsmith-salinas/.codex/visualizations/2026/11/07/01a1b7dc-0f75-7863-aacb-8a55034cfcd6/screenshots/today-compact-2026-11-12/index.html).
