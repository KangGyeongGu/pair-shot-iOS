import Foundation
import OSLog
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
            AppLogger.subscription
                .info(
                    "RenewalReminder skip product=\(productID, privacy: .public) reason=trigger_in_past",
                )
            return
        }

        guard await ensureAuthorization() else {
            AppLogger.subscription
                .info(
                    "RenewalReminder skip product=\(productID, privacy: .public) reason=permission_denied",
                )
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

        do {
            try await center.add(request)
            AppLogger.subscription
                .info(
                    "RenewalReminder scheduled product=\(productID, privacy: .public) fire=\(triggerDate.timeIntervalSince1970, privacy: .public)",
                )
        } catch {
            AppLogger.subscription
                .error(
                    "RenewalReminder add failed product=\(productID, privacy: .public) error=\(error.localizedDescription, privacy: .public)",
                )
        }
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        AppLogger.subscription
            .info("RenewalReminder cancelAll removed=\(identifiers.count, privacy: .public)")
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
                do {
                    return try await center.requestAuthorization(options: [.alert, .sound])
                } catch {
                    AppLogger.subscription
                        .error(
                            "RenewalReminder authorization error=\(error.localizedDescription, privacy: .public)",
                        )
                    return false
                }

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
