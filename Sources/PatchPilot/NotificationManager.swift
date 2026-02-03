import Foundation
import UserNotifications

struct NotificationManager {
    func notifyUpdatesFound(count: Int) async {
        guard count > 0 else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let finalSettings = await center.notificationSettings()
        guard finalSettings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Updates available"
        content.body = count == 1 ? "1 app has an update." : "\(count) apps have updates."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        _ = try? await center.add(request)
    }
}
