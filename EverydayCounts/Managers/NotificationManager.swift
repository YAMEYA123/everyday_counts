import UserNotifications
import Foundation

class NotificationManager {
    static let shared = NotificationManager()

    private let hourKey = "reminder_hour"
    private let minuteKey = "reminder_minute"
    private let appGroupID = "group.com.yameya.everyday-counts"
    private let slotsPerDay = 3
    // Offsets in minutes after the primary reminder time
    private let slotOffsets = [0, 60, 120]
    private let slotBodies = [
        "今天还没有记录，拍一张照片吧 📷",
        "今天快过去了，还没拍照哦 🌙",
        "今天最后一次机会了，别错过 ✨"
    ]

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

    /// Schedule the next 7 days of reminders (3 decay slots per day).
    /// Automatically skips today if the user has already taken a photo.
    func scheduleDailyReminder() {
        guard UserDefaults.standard.bool(forKey: "reminderEnabled") else { return }
        let hasTakenToday = self.hasTakenToday()
        let cal = Calendar.current
        let now = Date()
        let center = UNUserNotificationCenter.current()

        // Remove all existing reminder requests before rescheduling
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers(daysAhead: 8))

        for dayOffset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            if dayOffset == 0 && hasTakenToday { continue }

            for (slotIndex, minuteOffset) in slotOffsets.enumerated() {
                guard let baseTime = reminderTime(on: day),
                      let fireDate = cal.date(byAdding: .minute, value: minuteOffset, to: baseTime),
                      fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Everyday Counts"
                content.body = slotBodies[slotIndex]
                content.sound = .default

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: identifier(for: day, slot: slotIndex),
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    /// Cancel today's remaining reminder slots (call after photo is saved).
    func cancelTodayReminder() {
        let ids = (0..<slotsPerDay).map { identifier(for: Date(), slot: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Cancel all pending reminders (call when user turns off the reminder toggle).
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIdentifiers(daysAhead: 8))
    }

    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    // MARK: - Private

    private func hasTakenToday() -> Bool {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        let checked = UserDefaults(suiteName: appGroupID)?.string(forKey: "widget_checked_date") ?? ""
        return checked == today
    }

    private func reminderTime(on day: Date) -> Date? {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        c.hour = reminderHour; c.minute = reminderMinute; c.second = 0
        return Calendar.current.date(from: c)
    }

    private func identifier(for date: Date, slot: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "reminder-\(f.string(from: date))-slot\(slot)"
    }

    private func allIdentifiers(daysAhead: Int) -> [String] {
        let cal = Calendar.current
        var ids: [String] = []
        for d in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: d, to: Date()) else { continue }
            for s in 0..<slotsPerDay { ids.append(identifier(for: day, slot: s)) }
        }
        return ids
    }
}
