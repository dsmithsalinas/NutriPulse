import Foundation

extension Notification.Name {
    static let smartCoachingSettingsChanged = Notification.Name("smartCoachingSettingsChanged")
}

enum SmartNotificationKind: String, Codable, CaseIterable {
    case workoutRecovery
    case proteinCloseout
    case lowAppetite
    case repeatedMeal
}

struct SmartNotificationOpportunity: Equatable {
    let kind: SmartNotificationKind
    let priority: Int
    let title: String
    let body: String
    let rationale: String
    let fireDate: Date
    let sourceDate: String?
    let meal: Meal?
}

struct RepeatedMealPattern: Equatable {
    let meal: Meal
    let sourceDate: String
    let itemNames: [String]
    let occurrences: Int
    let usualMinuteOfDay: Int
}

enum RepeatedMealDetector {
    static func detect(
        history: [FoodLog],
        todayLogs: [FoodLog],
        now: Date,
        calendar: Calendar = .current
    ) -> RepeatedMealPattern? {
        struct MealKey: Hashable { let date: String; let meal: Meal }
        let grouped = Dictionary(grouping: history) { MealKey(date: $0.logDate, meal: $0.meal) }

        struct Occurrence {
            let signature: String
            let meal: Meal
            let date: String
            let names: [String]
            let minute: Int
        }

        let occurrences: [Occurrence] = grouped.compactMap { key, logs in
            guard !logs.isEmpty else { return nil }
            let signature = logs
                .map { "\($0.foodItemId.uuidString):\(String(format: "%.2f", $0.quantity))" }
                .sorted()
                .joined(separator: "|")
            let minutes = logs.map {
                calendar.component(.hour, from: $0.loggedAt) * 60 + calendar.component(.minute, from: $0.loggedAt)
            }
            return Occurrence(
                signature: "\(key.meal.rawValue)|\(signature)",
                meal: key.meal,
                date: key.date,
                names: Array(Set(logs.map(\.displayName))).sorted(),
                minute: minutes.reduce(0, +) / minutes.count
            )
        }

        let repeated = Dictionary(grouping: occurrences, by: \.signature)
            .values
            .filter { $0.count >= 3 }
            .compactMap { group -> RepeatedMealPattern? in
                guard let latest = group.max(by: { $0.date < $1.date }) else { return nil }
                let usual = group.reduce(0) { $0 + $1.minute } / group.count
                return RepeatedMealPattern(
                    meal: latest.meal,
                    sourceDate: latest.date,
                    itemNames: latest.names,
                    occurrences: group.count,
                    usualMinuteOfDay: usual
                )
            }

        let nowMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return repeated
            .filter { pattern in
                !todayLogs.contains(where: { $0.meal == pattern.meal })
                    && (7 * 60..<(21 * 60)).contains(pattern.usualMinuteOfDay)
                    && pattern.usualMinuteOfDay >= nowMinute - 45
                    && pattern.usualMinuteOfDay <= nowMinute + 240
            }
            .min { abs($0.usualMinuteOfDay - nowMinute) < abs($1.usualMinuteOfDay - nowMinute) }
    }
}

enum SmartNotificationEngine {
    static func bestOpportunity(
        recovery: RecoveryOpportunity?,
        proteinGap: Int,
        calorieRoom: Int,
        rescueOptions: [ProteinRescueOption],
        lowAppetite: LowAppetitePreparation? = nil,
        repeatedMeal: RepeatedMealPattern?,
        enabledKinds: Set<SmartNotificationKind> = Set(SmartNotificationKind.allCases),
        quietStartHour: Int = 21,
        quietEndHour: Int = 7,
        now: Date,
        calendar: Calendar = .current
    ) -> SmartNotificationOpportunity? {
        let hour = calendar.component(.hour, from: now)
        guard !isQuiet(hour: hour, start: quietStartHour, end: quietEndHour) else { return nil }

        if enabledKinds.contains(.workoutRecovery), let recovery, recovery.hasGap,
           now.timeIntervalSince(recovery.finishedAt) >= 0,
           now.timeIntervalSince(recovery.finishedAt) <= 90 * 60 {
            let gaps = [
                recovery.proteinGap > 0 ? "\(recovery.proteinGap)g protein" : nil,
                recovery.waterGapMl >= 250 ? "\(recovery.waterGapMl) ml water" : nil,
            ].compactMap { $0 }.joined(separator: " and ")
            return .init(
                kind: .workoutRecovery,
                priority: 3,
                title: "Recovery window is open",
                body: "Your \(recovery.workoutName.lowercased()) is done, with \(gaps) still on the board.",
                rationale: "A workout finished recently and your current protein or hydration logs still showed a recovery gap.",
                fireDate: now.addingTimeInterval(60),
                sourceDate: nil,
                meal: nil
            )
        }

        if enabledKinds.contains(.proteinCloseout), hour >= 15,
           (15...45).contains(proteinGap), let option = rescueOptions.first,
           option.calories <= max(calorieRoom, 0) + 100 {
            return .init(
                kind: .proteinCloseout,
                priority: 2,
                title: "Your protein floor is within reach",
                body: "\(proteinGap)g to go. \(option.title) would cover \(option.proteinG)g.",
                rationale: "You were 15–45g from your protein floor and Footing found an option that fits the remaining calorie room.",
                fireDate: now.addingTimeInterval(60),
                sourceDate: nil,
                meal: nil
            )
        }

        if enabledKinds.contains(.lowAppetite), hour < 18, let lowAppetite {
            return .init(
                kind: .lowAppetite,
                priority: 2,
                title: "Tomorrow may be a lower-appetite day",
                body: "Stage one small protein-dense option today so tomorrow takes less effort.",
                rationale: lowAppetite.detail,
                fireDate: now.addingTimeInterval(60),
                sourceDate: nil,
                meal: nil
            )
        }

        if enabledKinds.contains(.repeatedMeal), let pattern = repeatedMeal {
            let nowMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            let targetMinute = max(pattern.usualMinuteOfDay, nowMinute)
            let fireDate = calendar.date(
                bySettingHour: targetMinute / 60,
                minute: targetMinute % 60,
                second: 0,
                of: now
            ) ?? now.addingTimeInterval(60)
            let names = pattern.itemNames.prefix(3).joined(separator: ", ")
            return .init(
                kind: .repeatedMeal,
                priority: 1,
                title: "Your usual \(pattern.meal.rawValue)?",
                body: "You've logged \(names) around this time \(pattern.occurrences) times recently.",
                rationale: "The same \(pattern.meal.rawValue) appeared around this time on \(pattern.occurrences) recent days, and no \(pattern.meal.rawValue) is logged today.",
                fireDate: max(fireDate, now.addingTimeInterval(60)),
                sourceDate: pattern.sourceDate,
                meal: pattern.meal
            )
        }

        return nil
    }

    static func isQuiet(hour: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        if start > end { return hour >= start || hour < end }
        return hour >= start && hour < end
    }
}

struct SmartNotificationRoute: Codable, Equatable, Identifiable {
    enum Action: String, Codable {
        case closeProtein
        case addWater
        case repeatMeal
        case reviewMeal
        case viewPreparation
    }
    let action: Action
    let sourceDate: String?
    let mealRawValue: String?

    var meal: Meal? { mealRawValue.flatMap(Meal.init(rawValue:)) }
    var id: String { "\(action.rawValue)-\(sourceDate ?? "")-\(mealRawValue ?? "")" }
}

enum SmartNotificationRouteStore {
    private static let key = "pendingSmartNotificationRoute"

    static func save(_ route: SmartNotificationRoute) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func consume() -> SmartNotificationRoute? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let route = try? JSONDecoder().decode(SmartNotificationRoute.self, from: data) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return route
    }
}
