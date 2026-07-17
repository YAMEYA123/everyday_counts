import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private let identifier = "daily-reminder"
    private let hourKey = "reminder_hour"
    private let minuteKey = "reminder_minute"

    var reminderHour: Int {
        get { UserDefaults.standard.object(forKey: hourKey) as? Int ?? 20 }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }
    var reminderMinute: Int {
        get { UserDefaults.standard.object(forKey: minuteKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: minuteKey) }
    }
    var reminderDate: Date {
        get {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            c.hour = reminderHour; c.minute = reminderMinute
            return Calendar.current.date(from: c) ?? Date()
        }
        set {
            reminderHour = Calendar.current.component(.hour, from: newValue)
            reminderMinute = Calendar.current.component(.minute, from: newValue)
        }
    }

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
        components.hour = reminderHour
        components.minute = reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    func cancelTodayReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}
