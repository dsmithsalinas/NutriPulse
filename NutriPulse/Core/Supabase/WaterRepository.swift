import Foundation
import Supabase

struct WaterRepository {
    func fetchTotal(for date: Date) async throws -> Double {
        struct Row: Decodable {
            let amountMl: Double
            enum CodingKeys: String, CodingKey { case amountMl = "amount_ml" }
        }
        let rows: [Row] = try await supabase
            .from("water_logs")
            .select("amount_ml")
            .eq("log_date", value: date.isoDateString)
            .execute()
            .value
        return rows.reduce(0) { $0 + $1.amountMl }
    }

    func add(_ ml: Double, for date: Date) async throws {
        struct NewWaterLog: Encodable {
            let userId: UUID
            let loggedAt: Date
            let logDate: String
            let amountMl: Double
            let source: String
            enum CodingKeys: String, CodingKey {
                case userId   = "user_id"
                case loggedAt = "logged_at"
                case logDate  = "log_date"
                case amountMl = "amount_ml"
                case source
            }
        }
        let userId = try await supabase.auth.session.user.id
        try await supabase
            .from("water_logs")
            .insert(NewWaterLog(
                userId: userId,
                loggedAt: .now,
                logDate: date.isoDateString,
                amountMl: ml,
                source: "manual"
            ))
            .execute()
    }
}
