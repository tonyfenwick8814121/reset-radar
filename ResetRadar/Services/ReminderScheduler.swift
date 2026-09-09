import Foundation
import UserNotifications

actor ReminderScheduler {
    static let shared = ReminderScheduler()

    func schedule(_ event: ResetEvent, preferences: UserPreferences) async {
        guard let target = event.targetAt, target > Date() else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        let current = await center.notificationSettings()
        guard current.authorizationStatus == .authorized || current.authorizationStatus == .provisional else { return }
        let identifiers = preferences.reminderOffsets.map { identifier(event: event, offset: $0) } + [identifier(event: event, offset: 0)]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for reminder in ReminderPlanner.plan(target: target, offsets: preferences.reminderOffsets, now: Date()) {
            let content = UNMutableNotificationContent()
            content.title = preferences.locale == .zhHans ? "归零 · Reset Radar" : "Reset Radar"
            content.body = body(offset: reminder.offset, locale: preferences.locale)
            if preferences.audioEnabled { content.sound = .default }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(event: event, offset: reminder.offset), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private func identifier(event: ResetEvent, offset: TimeInterval) -> String {
        "reset-radar.\(event.id).r\(event.revision).\(Int(offset))"
    }

    private func body(offset: TimeInterval, locale: AppLocale) -> String {
        if offset == 0 { return locale == .zhHans ? "已到预计重置时间，等待确认。" : "The estimated reset time has arrived. Awaiting confirmation." }
        let minutes = Int(offset / 60)
        return locale == .zhHans ? "预计 \(minutes) 分钟后重置。" : "Estimated reset in \(minutes) minutes."
    }
}

struct PlannedReminder: Equatable {
    let offset: TimeInterval
    let fireDate: Date
}

enum ReminderPlanner {
    static func plan(target: Date, offsets: [TimeInterval], now: Date) -> [PlannedReminder] {
        (offsets + [0])
            .map { PlannedReminder(offset: $0, fireDate: target.addingTimeInterval(-$0)) }
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
    }
}
