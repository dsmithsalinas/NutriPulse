import Foundation
import Supabase

struct ExperimentRepository {
    func fetchAll() async throws -> [PersonalExperiment] {
        try await supabase
            .from("personal_experiments")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func create(
        question: String,
        interventionGoalId: UUID,
        outcome: ExperimentOutcomeTemplate,
        durationDays: Int = 21
    ) async throws {
        let userId = try await supabase.auth.session.user.id
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: max(durationDays, 1) - 1, to: start)!

        let experiment: PersonalExperiment = try await supabase
            .from("personal_experiments")
            .insert(NewExperiment(
                userId: userId,
                interventionGoalId: interventionGoalId,
                question: question,
                interventionStart: start.isoDateString,
                endDate: end.isoDateString
            ))
            .select()
            .single()
            .execute()
            .value

        let metric: ExperimentMetric = try await supabase
            .from("experiment_metrics")
            .insert(NewExperimentMetric(
                userId: userId, name: outcome.name,
                aggregation: outcome.aggregation, unit: outcome.unit,
                sourceType: outcome.sourceType, sourceMetric: outcome.sourceMetric
            ))
            .select()
            .single()
            .execute()
            .value

        try await supabase
            .from("experiment_measurements")
            .insert(NewExperimentMeasurement(
                experimentId: experiment.id, measurementId: metric.id,
                userId: userId, role: "primary_outcome"
            ))
            .execute()
    }
}

private struct NewExperiment: Encodable {
    let userId: UUID
    let interventionGoalId: UUID
    let question: String
    let status = ExperimentStatus.running
    let interventionStart: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case interventionGoalId = "intervention_goal_id"
        case question, status
        case interventionStart = "intervention_start"
        case endDate = "end_date"
    }
}

private struct NewExperimentMetric: Encodable {
    let userId: UUID
    let name: String
    let aggregation: GoalAggregation
    let unit: String
    let sourceType: GoalSourceType
    let sourceMetric: GoalSourceMetric?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, aggregation, unit
        case sourceType = "source_type"
        case sourceMetric = "source_metric"
    }
}

private struct NewExperimentMeasurement: Encodable {
    let experimentId: UUID
    let measurementId: UUID
    let userId: UUID
    let role: String

    enum CodingKeys: String, CodingKey {
        case experimentId = "experiment_id"
        case measurementId = "measurement_id"
        case userId = "user_id"
        case role
    }
}
