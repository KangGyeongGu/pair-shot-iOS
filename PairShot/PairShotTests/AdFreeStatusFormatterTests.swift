import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P8.5 — pure-function coverage for ``AdFreeStatusFormatter``. The view
/// renders these strings directly so we guarantee the day-count clamping
/// and the inactive-headline branch don't drift.
@MainActor
final class AdFreeStatusFormatterTests: XCTestCase {
    // MARK: - remainingDays — happy

    func testRemainingDaysPositiveInterval() {
        let now = Self.makeDate(year: 2026, month: 4, day: 26)
        let later = Self.makeDate(year: 2026, month: 5, day: 6)
        let days = AdFreeStatusFormatter.remainingDays(until: later, now: now)
        XCTAssertEqual(days, 10)
    }

    func testRemainingDaysSameDayIsZero() {
        let now = Self.makeDate(year: 2026, month: 4, day: 26)
        let sameDay = Self.makeDate(year: 2026, month: 4, day: 26, hour: 23)
        let days = AdFreeStatusFormatter.remainingDays(until: sameDay, now: now)
        XCTAssertEqual(days, 0)
    }

    // MARK: - remainingDays — edge

    func testRemainingDaysNegativeClampsToZero() {
        let now = Self.makeDate(year: 2026, month: 4, day: 26)
        let past = Self.makeDate(year: 2026, month: 4, day: 1)
        let days = AdFreeStatusFormatter.remainingDays(until: past, now: now)
        XCTAssertEqual(days, 0, "Past expirations must surface as 0, not negative")
    }

    // MARK: - headline — happy + edge

    func testHeadlineInactiveWhenNotAdFree() {
        let headline = AdFreeStatusFormatter.headline(
            isAdFree: false,
            latestExpiration: nil,
            now: .now
        )
        XCTAssertTrue(headline.contains("비활성"), "got: \(headline)")
    }

    func testHeadlineInactiveWhenExpirationMissingEvenIfFlagTrue() {
        // `isAdFree` true but expiration missing should still render the
        // inactive headline rather than print a bogus "?일".
        let headline = AdFreeStatusFormatter.headline(
            isAdFree: true,
            latestExpiration: nil,
            now: .now
        )
        XCTAssertTrue(headline.contains("비활성"), "got: \(headline)")
    }

    func testHeadlineActiveContainsRemainingDaysAndDate() {
        let now = Self.makeDate(year: 2026, month: 4, day: 26)
        let later = Self.makeDate(year: 2026, month: 7, day: 26)
        let headline = AdFreeStatusFormatter.headline(
            isAdFree: true,
            latestExpiration: later,
            now: now
        )
        XCTAssertTrue(headline.contains("활성"), "got: \(headline)")
        XCTAssertTrue(headline.contains("2026-07-26"), "got: \(headline)")
        // 91 days from 2026-04-26 (April 30 + May 31 + June 30 + 0 = 91).
        XCTAssertTrue(headline.contains("91"), "got: \(headline)")
    }

    // MARK: - maskCode — happy + edge

    func testMaskCodeMasksAllButLastFour() {
        XCTAssertEqual(
            AdFreeStatusFormatter.maskCode("ABCD-EFGH-IJKL-MNOP"),
            "****-MNOP"
        )
    }

    func testMaskCodeShortStringPassesThrough() {
        XCTAssertEqual(AdFreeStatusFormatter.maskCode("WXYZ"), "WXYZ")
        XCTAssertEqual(AdFreeStatusFormatter.maskCode("AB"), "AB")
    }

    func testMaskCodeEmptyOrWhitespaceCollapsesToStars() {
        XCTAssertEqual(AdFreeStatusFormatter.maskCode(""), "****")
        XCTAssertEqual(AdFreeStatusFormatter.maskCode("   "), "****")
    }

    // MARK: - pastStatusLabel

    func testPastStatusLabelMapsCases() {
        let revoked = Coupon(
            code: "R",
            durationDays: 0,
            signatureBase64: "x",
            status: .revoked
        )
        let expired = Coupon(
            code: "E",
            durationDays: 0,
            signatureBase64: "x",
            status: .expired
        )
        let stillActive = Coupon(
            code: "S",
            durationDays: 0,
            signatureBase64: "x",
            status: .active
        )
        XCTAssertEqual(AdFreeStatusFormatter.pastStatusLabel(for: revoked), "취소")
        XCTAssertEqual(AdFreeStatusFormatter.pastStatusLabel(for: expired), "만료")
        // `.active` in the past section means "expired but not rolled
        // over" — the formatter labels it the same as expired.
        XCTAssertEqual(AdFreeStatusFormatter.pastStatusLabel(for: stillActive), "만료")
    }

    // MARK: - helpers

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components) ?? .now
    }
}
