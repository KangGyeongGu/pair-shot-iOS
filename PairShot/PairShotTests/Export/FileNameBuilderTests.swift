import Foundation
@testable import PairShot
import Testing

struct FileNameBuilderTests {
    private static let frozenTimestamp: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = 2026
        components.month = 5
        components.day = 19
        components.hour = 14
        components.minute = 30
        components.second = 45
        guard let date = components.date else {
            fatalError("frozenTimestamp components must be valid")
        }
        return date
    }()

    private static let expectedDateStr = "20260519"
    private static let expectedTimeStr = "143045"

    @Test
    func `before 파일명은 prefix-BEFORE-seq-date-time-ext 패턴`() {
        let name = FileNameBuilder.before(
            prefix: "Site",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 1,
            fileExtension: "jpg",
        )
        #expect(name == "Site_BEFORE_001_\(Self.expectedDateStr)_\(Self.expectedTimeStr).jpg")
    }

    @Test
    func `after 파일명은 prefix-AFTER-seq-date-time-ext 패턴`() {
        let name = FileNameBuilder.after(
            prefix: "Site",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 1,
            fileExtension: "jpg",
        )
        #expect(name == "Site_AFTER_001_\(Self.expectedDateStr)_\(Self.expectedTimeStr).jpg")
    }

    @Test
    func `combined 파일명은 prefix-PAIR-seq-date-time-ext 패턴`() {
        let name = FileNameBuilder.combined(
            prefix: "Site",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 1,
            fileExtension: "jpg",
        )
        #expect(name == "Site_PAIR_001_\(Self.expectedDateStr)_\(Self.expectedTimeStr).jpg")
    }

    @Test
    func `sequenceNumber 는 3자리 zero-padding 됨`() {
        let one = FileNameBuilder.before(
            prefix: "P",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 1,
        )
        let forty2 = FileNameBuilder.before(
            prefix: "P",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 42,
        )
        let big = FileNameBuilder.before(
            prefix: "P",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 1234,
        )

        #expect(one.contains("_001_"))
        #expect(forty2.contains("_042_"))
        #expect(big.contains("_1234_"))
    }

    @Test
    func `fileExtension 변경시 끝부분에 그대로 반영`() {
        let jpg = FileNameBuilder.before(
            prefix: "Site",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 5,
            fileExtension: "jpg",
        )
        let heic = FileNameBuilder.before(
            prefix: "Site",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 5,
            fileExtension: "heic",
        )

        #expect(jpg.hasSuffix(".jpg"))
        #expect(heic.hasSuffix(".heic"))
    }

    @Test
    func `prefix 빈문자열이면 prefix 구획 자체 생략 (언더스코어로 시작하지 않음)`() {
        let name = FileNameBuilder.before(
            prefix: "",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 1,
        )
        #expect(name.hasPrefix("BEFORE_"))
        #expect(!name.hasPrefix("_BEFORE"))
    }

    @Test
    func `prefix 의 금지문자는 sanitize 되어 파일명에서 제거됨`() {
        let name = FileNameBuilder.before(
            prefix: "A/B:C",
            timestamp: Self.frozenTimestamp,
            sequenceNumber: 1,
        )
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(name.contains("ABC_BEFORE_"))
    }
}
