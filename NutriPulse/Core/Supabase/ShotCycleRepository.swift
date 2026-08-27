import Foundation
import Supabase

struct ShotCycleRepository {
    func fetchRecent(days: Int = 42) async throws -> [ShotCycleCheckIn] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        return try await supabase
            .from("shot_cycle_checkins")
            .select()
            .gte("checkin_date", value: start.isoDateString)
            .order("checkin_date", ascending: false)
            .execute()
            .value
    }

    func save(_ draft: ShotCycleCheckInDraft, cycleDay: Int) async throws -> ShotCycleCheckIn {
        let userId = try await supabase.auth.session.user.id
        let cleanNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = NewShotCycleCheckIn(
            userId: userId,
            checkinDate: Date.now.isoDateString,
            cycleDay: min(max(cycleDay, 0), 30),
            appetite: draft.appetite,
            fullness: draft.fullness,
            nausea: draft.nausea,
            energy: draft.energy,
            digestion: draft.digestion,
            note: cleanNote.isEmpty ? nil : cleanNote
        )
        return try await supabase
            .from("shot_cycle_checkins")
            .upsert(payload, onConflict: "user_id,checkin_date")
            .select()
            .single()
            .execute()
            .value
    }
}
