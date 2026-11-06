import Foundation
import Supabase

@MainActor
struct RemoteMedicationTransport: MedicationTransport {
    func fetch(owner: UUID) async throws -> MedicationRemoteRecord? {
        guard try await supabase.auth.session.user.id == owner else { throw MedicationError.unavailable }
        let records: [MedicationRemoteRecord] = try await supabase.from("medication_tracking")
            .select().eq("user_id", value: owner).execute().value
        guard supabase.auth.currentSession?.user.id == owner else { throw MedicationError.unavailable }
        return records.first
    }
    func save(owner: UUID, document: MedicationDocument, expectedRevision: Int, writeID: UUID) async throws -> MedicationRemoteRecord {
        guard try await supabase.auth.session.user.id == owner else { throw MedicationError.unavailable }
        struct Payload: Encodable {
            var expected_revision: Int
            var new_document: MedicationDocument
            var new_write_id: UUID
        }
        let records: [MedicationRemoteRecord] = try await supabase.rpc("save_medication_tracking", params:
            Payload(expected_revision: expectedRevision, new_document: document, new_write_id: writeID))
            .execute().value
        guard supabase.auth.currentSession?.user.id == owner else { throw MedicationError.unavailable }
        guard let result = records.first else { throw MedicationError.conflict }
        return result
    }
}
