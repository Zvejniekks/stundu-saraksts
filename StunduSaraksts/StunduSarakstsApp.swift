import SwiftUI
import UserNotifications

/// Shows change and new-week notifications even while the app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

@main
struct StunduSarakstsApp: App {
    init() { UNUserNotificationCenter.current().delegate = NotificationPresenter.shared }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .backgroundTask(.appRefresh(ChangeNotifier.taskID)) {
            ChangeNotifier.scheduleBackgroundRefresh()
            await ChangeNotifier.check()
        }
    }
}
