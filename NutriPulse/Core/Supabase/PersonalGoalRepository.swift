import Foundation
import Supabase

struct PersonalGoalRepository {
    func fetchActiveGoals() async throws -> [PersonalGoalBundle] {
        try await fetchGoals(status: .active, ascending: true)
    }

    func fetchCompletedGoals() async throws -> [PersonalGoalBundle] {
        try await fetchGoals(status: .completed, ascending: false)
    }

    private func fetchGoals(
        status: GoalStatus,
        ascending: Bool
    ) async throws -> [PersonalGoalBundle] {
        let goals: [PersonalGoal] = try await supabase
            .from("personal_goals")
            .select()
            .eq("status", value: status.rawValue)
            .order(status == .completed ? "completed_at" : "created_at", ascending: ascending)
            .execute()
            .value

        var bundles: [PersonalGoalBundle] = []
        for goal in goals {
            guard let versionId = goal.currentVersionId else { continue }
            let versions: [GoalVersion] = try await supabase
                .from("goal_versions")
                .select()
                .eq("id", value: versionId)
                .limit(1)
                .execute()
                .value
            guard let version = versions.first else { continue }

            async let measurementTask: [GoalMeasurement] = supabase
                .from("goal_measurements")
                .select()
                .eq("goal_version_id", value: version.id)
                .order("created_at", ascending: true)
                .execute()
                .value
            async let checkinTask: [GoalCheckin] = supabase
                .from("goal_checkins")
                .select()
                .eq("goal_id", value: goal.id)
                .gte("local_date", value: version.startDate)
                .order("observed_at", ascending: true)
                .execute()
                .value

            let (measurements, checkins) = try await (measurementTask, checkinTask)
            var observations: [GoalObservation] = []
            for measurement in measurements {
                let rows: [GoalObservation] = try await supabase
                    .from("goal_observations")
                    .select()
                    .eq("measurement_id", value: measurement.id)
                    .order("created_at", ascending: true)
                    .execute()
                    .value
                observations.append(contentsOf: rows)
            }
            bundles.append(.init(
                goal: goal, version: version, measurements: measurements,
                checkins: checkins, observations: observations
            ))
        }
        return bundles
    }

    func createGoal(from template: GoalTemplate, startDate: Date = .now) async throws {
        try await createGoal(from: GoalDraft(template: template), startDate: startDate)
    }

    func createGoal(
        from draft: GoalDraft,
        status: GoalStatus = .active,
        startDate: Date = .now
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        let goal: PersonalGoal = try await supabase
            .from("personal_goals")
            .insert(NewGoal(userId: userId, status: status))
            .select()
            .single()
            .execute()
            .value

        let start = Calendar.current.startOfDay(for: startDate)
        let end: Date?
        if draft.period == .custom {
            end = Calendar.current.date(byAdding: .day, value: draft.durationDays - 1, to: start)
        } else if draft.period == .daily {
            end = start
        } else if draft.period == .monthly {
            end = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        } else if draft.period == .annual {
            end = Calendar.current.date(byAdding: DateComponents(year: 1, day: -1), to: start)
        } else {
            end = nil
        }

        let version: GoalVersion = try await supabase
            .from("goal_versions")
            .insert(NewGoalVersion(
                goalId: goal.id,
                userId: userId,
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: draft.detail.isEmpty ? draft.trackingSource.detail : draft.detail,
                period: draft.period,
                startDate: start.isoDateString,
                endDate: end?.isoDateString,
                timezoneId: TimeZone.current.identifier,
                effectiveFrom: start.isoDateString
            ))
            .select()
            .single()
            .execute()
            .value

        _ = try await supabase
            .from("goal_measurements")
            .insert(NewGoalMeasurement(
                goalVersionId: version.id,
                userId: userId,
                name: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: draft.kind,
                aggregation: draft.aggregation,
                comparison: draft.comparison,
                targetValue: draft.targetValue,
                unit: draft.unit.isEmpty ? nil : draft.unit,
                sourceType: draft.trackingSource.sourceType,
                sourceMetric: draft.sourceMetric
            ))
            .execute()

        try await supabase
            .from("personal_goals")
            .update(CurrentVersionUpdate(currentVersionId: version.id))
            .eq("id", value: goal.id)
            .execute()
    }

    func recordBoolean(
        _ value: Bool,
        for bundle: PersonalGoalBundle,
        date: Date = .now
    ) async throws {
        guard let measurement = bundle.primaryMeasurement else { return }
        let userId = try await supabase.auth.session.user.id
        let checkin: GoalCheckin = try await supabase
            .from("goal_checkins")
            .insert(NewCheckin(
                id: UUID(), goalId: bundle.goal.id, userId: userId,
                observedAt: date, localDate: date.isoDateString
            ))
            .select()
            .single()
            .execute()
            .value

        try await supabase
            .from("goal_observations")
            .insert(NewBooleanObservation(
                id: UUID(), checkinId: checkin.id,
                measurementId: measurement.id, userId: userId, valueBoolean: value
            ))
            .execute()
    }

    func recordNumber(
        _ value: Double,
        for bundle: PersonalGoalBundle,
        date: Date = .now
    ) async throws {
        guard let measurement = bundle.primaryMeasurement else { return }
        let userId = try await supabase.auth.session.user.id
        let checkin: GoalCheckin = try await supabase
            .from("goal_checkins")
            .insert(NewCheckin(
                id: UUID(), goalId: bundle.goal.id, userId: userId,
                observedAt: date, localDate: date.isoDateString
            ))
            .select()
            .single()
            .execute()
            .value

        try await supabase
            .from("goal_observations")
            .insert(NewNumberObservation(
                id: UUID(), checkinId: checkin.id,
                measurementId: measurement.id, userId: userId, valueNumber: value
            ))
            .execute()
    }

    func complete(_ goalId: UUID) async throws {
        try await supabase
            .from("personal_goals")
            .update(GoalStatusUpdate(status: .completed, completedAt: .now))
            .eq("id", value: goalId)
            .execute()
    }
}

private struct NewGoal: Encodable {
    let userId: UUID
    let status: GoalStatus
    enum CodingKeys: String, CodingKey { case userId = "user_id"; case status }
}

private struct NewGoalVersion: Encodable {
    let goalId: UUID
    let userId: UUID
    let versionNumber = 1
    let title: String
    let detail: String?
    let period: GoalPeriod
    let startDate: String
    let endDate: String?
    let timezoneId: String
    let scheduledWeekdays = [1, 2, 3, 4, 5, 6, 7]
    let effectiveFrom: String

    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case userId = "user_id"
        case versionNumber = "version_number"
        case title, detail, period
        case startDate = "start_date"
        case endDate = "end_date"
        case timezoneId = "timezone_id"
        case scheduledWeekdays = "scheduled_weekdays"
        case effectiveFrom = "effective_from"
    }
}

private struct NewGoalMeasurement: Encodable {
    let goalVersionId: UUID
    let userId: UUID
    let role = "primary"
    let name: String
    let kind: GoalMeasurementKind
    let aggregation: GoalAggregation
    let comparison: GoalComparison
    let targetValue: Double?
    let unit: String?
    let sourceType: GoalSourceType
    let sourceMetric: GoalSourceMetric?

    enum CodingKeys: String, CodingKey {
        case goalVersionId = "goal_version_id"
        case userId = "user_id"
        case role, name, kind, aggregation, comparison
        case targetValue = "target_value"
        case unit
        case sourceType = "source_type"
        case sourceMetric = "source_metric"
    }
}

private struct CurrentVersionUpdate: Encodable {
    let currentVersionId: UUID
    enum CodingKeys: String, CodingKey { case currentVersionId = "current_version_id" }
}

private struct NewCheckin: Encodable {
    let id: UUID
    let goalId: UUID
    let userId: UUID
    let observedAt: Date
    let localDate: String
    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case userId = "user_id"
        case observedAt = "observed_at"
        case localDate = "local_date"
    }
}

private struct NewBooleanObservation: Encodable {
    let id: UUID
    let checkinId: UUID
    let measurementId: UUID
    let userId: UUID
    let valueBoolean: Bool
    enum CodingKeys: String, CodingKey {
        case id
        case checkinId = "checkin_id"
        case measurementId = "measurement_id"
        case userId = "user_id"
        case valueBoolean = "value_boolean"
    }
}

private struct NewNumberObservation: Encodable {
    let id: UUID
    let checkinId: UUID
    let measurementId: UUID
    let userId: UUID
    let valueNumber: Double
    enum CodingKeys: String, CodingKey {
        case id
        case checkinId = "checkin_id"
        case measurementId = "measurement_id"
        case userId = "user_id"
        case valueNumber = "value_number"
    }
}

private struct GoalStatusUpdate: Encodable {
    let status: GoalStatus
    let completedAt: Date
    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
    }
}
