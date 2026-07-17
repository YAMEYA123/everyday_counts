import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private let identifier = "daily-reminder"

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Everyday Counts"
        content.body = "今天还没有记录，拍一张照片吧 📷"
        content.sound = .default
        var components = DateComponents()
        components.hour = 20; components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    func cancelTodayReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
