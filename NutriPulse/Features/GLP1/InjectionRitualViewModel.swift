import Observation
import Foundation

@Observable
@MainActor
final class InjectionRitualViewModel {
    var medication: GLP1Medication = .zepbound
    var doseMg: Double = 2.5
    var site: InjectionSite = .leftAbdomen
    var isLogging = false
    var errorMessage: String?

    private let glp1Repo = GLP1Repository()
    private static let plannedDoseKey = "glp1PlannedDoseMg"

    // The dose we pre-filled with (before any change), so a one-off can be pinned back.
    private var defaultAtLoad: Double = 2.5

    var doses: [Double] { medication.availableDoses }
    var canStepDown: Bool { (doses.firstIndex(of: doseMg) ?? 0) > 0 }
    var canStepUp: Bool { (doses.firstIndex(of: doseMg) ?? (doses.count - 1)) < doses.count - 1 }
    private(set) var previousSite: String?

    func load(from latest: GLP1Log?) {
        guard let latest else { return }
        medication = GLP1Medication(rawValue: latest.medication) ?? .zepbound

        // Pre-fill dose: a planned override wins, else the last logged dose — clamped to the
        // medication's real ladder so we never show an off-ladder value.
        let planned = UserDefaults.standard.object(forKey: Self.plannedDoseKey) as? Double
        let candidate = planned ?? latest.doseMg
        doseMg = medication.availableDoses.contains(candidate)
            ? candidate
            : (medication.availableDoses.first ?? latest.doseMg)
        defaultAtLoad = doseMg

        // Suggest the next site in the rotation after the last one used.
        previousSite = latest.site
        if let last = latest.site.flatMap(InjectionSite.init(rawValue:)),
           let idx = InjectionSite.allCases.firstIndex(of: last) {
            site = InjectionSite.allCases[(idx + 1) % InjectionSite.allCases.count]
        }
    }

    func stepDose(_ direction: Int) {
        guard let i = doses.firstIndex(of: doseMg) else { doseMg = doses.first ?? doseMg; return }
        doseMg = doses[min(max(i + direction, 0), doses.count - 1)]
    }

    // Logs today's injection and schedules reminders; returns the saved row so the caller can
    // update immediately (no refetch race). `updateGoingForward` persists the chosen dose as the
    // new default; when off, we pin the *previous* default so a one-off week doesn't silently
    // become next week's suggestion.
    func confirm(updateGoingForward: Bool) async -> GLP1Log? {
        isLogging = true
        defer { isLogging = false }

        let now = Date.now
        let nextDue = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        do {
            let saved = try await glp1Repo.logInjection(
                medication: medication.rawValue, doseMg: doseMg,
                site: site.rawValue, injectedAt: now, nextDueAt: nextDue
            )
            UserDefaults.standard.set(updateGoingForward ? doseMg : defaultAtLoad,
                                      forKey: Self.plannedDoseKey)
            await NotificationManager.shared.scheduleGLP1Reminders(nextDueAt: nextDue)
            return saved
        } catch {
            errorMessage = "Couldn't log your dose. Try again."
            return nil
        }
    }
}
