import UIKit
import UserNotifications

// SwiftUI synthesises an AppDelegate automatically, but its async handling of
// handleEventsForBackgroundURLSession crashes when the Supabase SDK registers
// a background URLSession. Providing a real AppDelegate takes over that slot.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerSmartCategories()
        HealthKitManager.shared.startWorkoutObservation {
            await SmartNotificationCoordinator.shared.evaluateAfterWorkout()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Supabase uses background URLSessions for auth token refresh.
        // Calling the completionHandler immediately tells iOS we've acknowledged
        // the events; Supabase's URLSession delegate handles the actual work.
        completionHandler()
    }

    // If Footing is already open, the useful context is visible in-app. Suppress the
    // banner instead of interrupting the user while they're looking at the answer.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        SmartNotificationHistoryStore.setStatus(.delivered, for: notification.request.identifier)
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let notificationID = response.notification.request.identifier
        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            SmartNotificationHistoryStore.setStatus(.dismissed, for: notificationID)
            return
        }
        if response.actionIdentifier == NotificationManager.notTodayAction {
            SmartNotificationHistoryStore.setStatus(.dismissed, for: notificationID)
            UserDefaults.standard.set(Date.now.isoDateString, forKey: NotificationManager.smartSuppressedDayKey)
            NotificationManager.shared.cancelSmartNotifications()
            return
        }
        let info = response.notification.request.content.userInfo
        let sourceDate = (info["sourceDate"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let meal = (info["meal"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let kind = (info["kind"] as? String).flatMap(SmartNotificationKind.init(rawValue:))

        let action: SmartNotificationRoute.Action?
        switch response.actionIdentifier {
        case NotificationManager.closeProteinAction: action = .closeProtein
        case NotificationManager.addWaterAction: action = .addWater
        case NotificationManager.repeatMealAction: action = .repeatMeal
        case NotificationManager.reviewMealAction: action = .reviewMeal
        case UNNotificationDefaultActionIdentifier:
            action = switch kind {
            case .repeatedMeal: .reviewMeal
            case .lowAppetite: .viewPreparation
            case .workoutRecovery, .proteinCloseout: .closeProtein
            case nil: nil
            }
        default: action = nil
        }
        guard let action else { return }
        SmartNotificationHistoryStore.setStatus(
            response.actionIdentifier == UNNotificationDefaultActionIdentifier ? .opened : .actioned,
            for: notificationID
        )
        SmartNotificationRouteStore.save(.init(
            action: action,
            sourceDate: sourceDate,
            mealRawValue: meal
        ))
    }
}
