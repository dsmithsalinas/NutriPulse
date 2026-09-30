import Foundation
import Supabase

struct ExperimentRepository {
    /// Experiments plus, best-effort, what each one is measuring — "Measuring: sleep hours" on
    /// the tile and the experiment list. The outcome read is additive and separate from the
    /// base fetch: if it fails, experiments still come back and simply show no outcome label.
    func fetchAll() async throws -> [PersonalExperiment] {
        let experiments: [PersonalExperiment] = try await supabase
            .from("personal_experiments")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        guard !experiments.isEmpty else { return experiments }
        guard let outcomesByExperiment = try? await fetchOutcomeMeasurements(
            for: experiments.map(\.id)
        ) else { return experiments }
        return experiments.map { experiment in
            var experiment = experiment
            experiment.outcomeMeasurements = outcomesByExperiment[experiment.id]
            return experiment
        }
    }

    /// `experiment_measurements` joined to `experiment_metrics`, grouped by experiment. A
    /// separate query (rather than embedding on the main select) so a failure here never takes
    /// down the experiment list itself.
    private func fetchOutcomeMeasurements(
        for experimentIds: [UUID]
    ) async throws -> [UUID: [ExperimentOutcomeMeasurement]] {
        struct Row: Decodable {
            let experimentId: UUID
            let measurementId: UUID
            let role: String
            let metric: ExperimentMetricSummary?
            enum CodingKeys: String, CodingKey {
                case experimentId = "experiment_id"
                case measurementId = "measurement_id"
                case role
                case metric = "experiment_metrics"
            }
        }
        let rows: [Row] = try await supabase
            .from("experiment_measurements")
            .select("experiment_id, measurement_id, role, experiment_metrics(name, unit)")
            .in("experiment_id", values: experimentIds)
            .execute()
            .value
        return Dictionary(grouping: rows, by: \.experimentId).mapValues { rows in
            rows.map { ExperimentOutcomeMeasurement(measurementId: $0.measurementId, role: $0.role, metric: $0.metric) }
        }
    }

    /// Daily values for one outcome measurement, oldest first — what `ExperimentComparisonEngine`
    /// compares against the intervention goal's own check-ins.
    func fetchOutcomeObservations(measurementId: UUID) async throws -> [ExperimentObservationValue] {
        struct Row: Decodable {
            let localDate: String
            let valueNumber: Double?
            let valueBoolean: Bool?
            enum CodingKeys: String, CodingKey {
                case localDate = "local_date"
                case valueNumber = "value_number"
                case valueBoolean = "value_boolean"
            }
        }
        let rows: [Row] = try await supabase
            .from("experiment_observations")
            .select("local_date, value_number, value_boolean")
            .eq("measurement_id", value: measurementId)
            .order("local_date", ascending: true)
            .execute()
            .value
        return rows.map { row in
            ExperimentObservationValue(
                localDate: row.localDate,
                number: row.valueNumber ?? row.valueBoolean.map { $0 ? 1 : 0 }
            )
        }
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
