import Foundation

@MainActor
enum PairLimitGate {
    static let freeTierDailyLimit: Int = 5

    static func shouldGatePairCreation(isPro: Bool, todayCreatedCount: Int) -> Bool {
        if isPro { return false }
        return todayCreatedCount >= freeTierDailyLimit
    }

    static func startOfToday(now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }
}
