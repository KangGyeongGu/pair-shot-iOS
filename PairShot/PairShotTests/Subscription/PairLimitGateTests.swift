import Foundation
@testable import PairShot
import Testing

@MainActor
struct PairLimitGateTests {
    @Test("Pro user is never gated regardless of today's count")
    func proIsNeverGated() {
        for count in [0, 3, 4, 5, 6, 100] {
            #expect(
                PairLimitGate.shouldGatePairCreation(isPro: true, todayCreatedCount: count) == false
            )
        }
    }

    @Test("Free user with today's count below 5 is not gated")
    func freeBelowLimitIsNotGated() {
        for count in 0 ..< PairLimitGate.freeTierDailyLimit {
            #expect(
                PairLimitGate.shouldGatePairCreation(isPro: false, todayCreatedCount: count) == false
            )
        }
    }

    @Test("Free user at exactly 5 pairs created today is gated")
    func freeAtLimitIsGated() {
        #expect(
            PairLimitGate.shouldGatePairCreation(
                isPro: false,
                todayCreatedCount: PairLimitGate.freeTierDailyLimit
            ) == true
        )
    }

    @Test("Free user above 5 pairs today is gated")
    func freeAboveLimitIsGated() {
        for count in [6, 7, 50] {
            #expect(
                PairLimitGate.shouldGatePairCreation(isPro: false, todayCreatedCount: count) == true
            )
        }
    }

    @Test("freeTierDailyLimit constant is 5")
    func freeTierDailyIsFive() {
        #expect(PairLimitGate.freeTierDailyLimit == 5)
    }

    @Test("startOfToday returns midnight in given calendar")
    func startOfTodayReturnsMidnight() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 14
        components.hour = 15
        components.minute = 42
        guard let now = calendar.date(from: components) else {
            Issue.record("Failed to construct test date")
            return
        }
        let dayStart = PairLimitGate.startOfToday(now: now, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dayStart)
        #expect(parts.year == 2026)
        #expect(parts.month == 5)
        #expect(parts.day == 14)
        #expect(parts.hour == 0)
        #expect(parts.minute == 0)
        #expect(parts.second == 0)
    }
}
