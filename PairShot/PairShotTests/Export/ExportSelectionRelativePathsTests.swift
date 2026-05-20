import Foundation
@testable import PairShot
import Testing

@MainActor
private enum Fixture {
    static let frozenTimestamp = Date(timeIntervalSinceReferenceDate: 700_000_000)

    static let allSelection = ExportContents(
        includeCombined: true,
        includeBefore: true,
        includeAfter: true,
    )

    static func makePair(
        beforeId: String? = "before-asset",
        afterId: String? = "after-asset",
        albumIds: [UUID] = [],
        createdAt: Date = frozenTimestamp,
    ) -> PhotoPair {
        PhotoPair(
            id: UUID(),
            beforePhotoLocalIdentifier: beforeId,
            afterPhotoLocalIdentifier: afterId,
            createdAt: createdAt,
            albumIds: albumIds,
        )
    }
}

@MainActor
struct ExportSelectionRelativePathsTests {
    @Test
    func `모든 selection + 양쪽 photo 존재시 COMBINED-BEFORE-AFTER 순 3 entries`() {
        let pair = Fixture.makePair()

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: Fixture.allSelection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        #expect(entries.count == 3)
        #expect(entries[0].kind == .combined)
        #expect(entries[1].kind == .before)
        #expect(entries[2].kind == .after)
        #expect(entries[0].relativeName.hasPrefix("COMBINED/"))
        #expect(entries[1].relativeName.hasPrefix("BEFORE/"))
        #expect(entries[2].relativeName.hasPrefix("AFTER/"))
        #expect(entries[0].localIdentifier == nil)
        #expect(entries[1].localIdentifier == "before-asset")
        #expect(entries[2].localIdentifier == "after-asset")
    }

    @Test
    func `selection 일부 (Before + After만)이면 해당 2 entries`() {
        let pair = Fixture.makePair()
        let selection = ExportContents(
            includeCombined: false,
            includeBefore: true,
            includeAfter: true,
        )

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: selection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        #expect(entries.count == 2)
        #expect(entries.map(\.kind) == [.before, .after])
    }

    @Test
    func `beforeId nil 이면 BEFORE 와 COMBINED 둘 다 생략 (AFTER 만 남음)`() {
        let pair = Fixture.makePair(beforeId: nil)

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: Fixture.allSelection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        #expect(entries.count == 1)
        #expect(entries.first?.kind == .after)
        #expect(entries.first?.relativeName.hasPrefix("AFTER/") == true)
    }

    @Test
    func `afterId nil 이면 AFTER 와 COMBINED 둘 다 생략 (BEFORE 만 남음)`() {
        let pair = Fixture.makePair(afterId: nil)

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: Fixture.allSelection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        #expect(entries.count == 1)
        #expect(entries.first?.kind == .before)
        #expect(entries.first?.relativeName.hasPrefix("BEFORE/") == true)
    }

    @Test
    func `양쪽 nil 이면 empty array`() {
        let pair = Fixture.makePair(beforeId: nil, afterId: nil)

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: Fixture.allSelection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        #expect(entries.isEmpty)
    }

    @Test
    func `beforeId 빈 문자열도 nil 과 동일하게 BEFORE-COMBINED 생략`() {
        let pair = Fixture.makePair(beforeId: "")

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: Fixture.allSelection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        #expect(entries.count == 1)
        #expect(entries.first?.kind == .after)
    }

    @Test
    func `albumIds 가 비어있어도 폴더는 평탄화된 BEFORE-AFTER-COMBINED 만 사용 (v5 회귀 차단)`() {
        let pair = Fixture.makePair(albumIds: [])

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: Fixture.allSelection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        let prefixes = entries.map { $0.relativeName.split(separator: "/").first.map(String.init) ?? "" }
        #expect(Set(prefixes) == Set(["COMBINED", "BEFORE", "AFTER"]))
        for entry in entries {
            #expect(entry.relativeName.split(separator: "/").count == 2)
        }
    }

    @Test
    func `albumIds 가 다양해도 폴더 구조 동일 (앨범 prefix 없음, v5 회귀 차단)`() {
        let multipleAlbums = [UUID(), UUID(), UUID()]
        let pair = Fixture.makePair(albumIds: multipleAlbums)

        let entries = ExportSelection.relativePaths(
            for: pair,
            selection: Fixture.allSelection,
            sequenceNumber: 1,
            prefix: "Site",
        )

        for entry in entries {
            let segments = entry.relativeName.split(separator: "/")
            #expect(segments.count == 2)
            #expect(["COMBINED", "BEFORE", "AFTER"].contains(String(segments[0])))
            for album in multipleAlbums {
                #expect(!entry.relativeName.contains(album.uuidString))
            }
        }
    }

    @Test
    func `prefix 와 fileExtension 변경시 relativeName 의 파일명 부분에 반영`() {
        let pair = Fixture.makePair()

        let defaultEntries = ExportSelection.relativePaths(
            for: pair,
            selection: ExportContents(includeCombined: false, includeBefore: true, includeAfter: false),
            sequenceNumber: 7,
            prefix: "Alpha",
            fileExtension: "jpg",
        )
        let heicEntries = ExportSelection.relativePaths(
            for: pair,
            selection: ExportContents(includeCombined: false, includeBefore: true, includeAfter: false),
            sequenceNumber: 7,
            prefix: "Beta",
            fileExtension: "heic",
        )

        let defaultName = try? #require(defaultEntries.first?.relativeName)
        let heicName = try? #require(heicEntries.first?.relativeName)
        #expect(defaultName?.contains("Alpha_") == true)
        #expect(defaultName?.hasSuffix(".jpg") == true)
        #expect(heicName?.contains("Beta_") == true)
        #expect(heicName?.hasSuffix(".heic") == true)
    }
}
