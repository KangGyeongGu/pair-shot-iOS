import Foundation
import UserNotifications

@MainActor
final class RenewalReminderScheduler {
    static let identifierPrefix = "renewal_reminder_"
    static let leadDays = 7

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent,
    ) {
        self.center = center
        self.calendar = calendar
    }

    func schedule(
        productID: String,
        expirationDate: Date,
        productDisplayName: String,
        now: Date = .now,
    ) async {
        guard let triggerDate = Self.reminderTriggerDate(
            expirationDate: expirationDate,
            leadDays: Self.leadDays,
            now: now,
            calendar: calendar,
        ) else {
            await removePending(productID: productID)
            return
        }

        guard await ensureAuthorization() else {
            return
        }

        let interval = triggerDate.timeIntervalSince(now)
        guard interval > 0 else {
            await removePending(productID: productID)
            return
        }

        let content = Self.makeContent(productDisplayName: productDisplayName)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let identifier = Self.identifier(for: productID)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    @discardableResult
    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true

            case .denied:
                return false

            case .notDetermined:
                return await (try? center.requestAuthorization(options: [.alert, .sound])) ?? false

            @unknown default:
                return false
        }
    }

    private func removePending(productID: String) async {
        let identifier = Self.identifier(for: productID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func identifier(for productID: String) -> String {
        identifierPrefix + productID
    }

    static func makeContent(productDisplayName: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "renewal_reminder_title")
        let template = String(localized: "renewal_reminder_body_template")
        content.body = String(format: template, productDisplayName)
        content.sound = .default
        return content
    }

    static func reminderTriggerDate(
        expirationDate: Date,
        leadDays: Int,
        now: Date,
        calendar: Calendar,
    ) -> Date? {
        guard let triggerDate = calendar.date(
            byAdding: .day,
            value: -leadDays,
            to: expirationDate,
        ) else { return nil }
        guard triggerDate > now else { return nil }
        return triggerDate
    }
}
