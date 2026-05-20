import Foundation
@testable import PairShot
import Testing

@MainActor
struct ExportJobBuilderTests {
    private static let fixedDate = Date(timeIntervalSinceReferenceDate: 750_000_000)

    @Test
    func `applyCombineSettings false — combineSettings nil + layout = appSettings_defaultCompositeLayout`() {
        let appSettings = Self.makeAppSettings()
        appSettings.defaultCompositeLayout = .vertical
        appSettings.combineSettings = CombineSettings(direction: .horizontal)
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )

        let jobs = ExportJobBuilder.makeJobs(
            pairs: [pair],
            selection: ExportContents(includeCombined: true, includeBefore: false, includeAfter: false),
            appSettings: appSettings,
            renderOptions: ExportRenderOptions(applyCombineSettings: false, isPro: true),
            now: Self.fixedDate,
        )

        #expect(!jobs.isEmpty)
        for job in jobs {
            #expect(job.combineSettings == nil)
            #expect(job.layout == .vertical)
        }
    }

    @Test
    func `applyCombineSettings true — combineSettings 적용 + layout = CompositeLayoutResolver 결과`() {
        let appSettings = Self.makeAppSettings()
        appSettings.defaultCompositeLayout = .horizontal
        let combine = CombineSettings(direction: .vertical)
        appSettings.combineSettings = combine
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )

        let jobs = ExportJobBuilder.makeJobs(
            pairs: [pair],
            selection: ExportContents(includeCombined: true, includeBefore: false, includeAfter: false),
            appSettings: appSettings,
            renderOptions: ExportRenderOptions(applyCombineSettings: true, isPro: true),
            now: Self.fixedDate,
        )

        #expect(!jobs.isEmpty)
        for job in jobs {
            #expect(job.combineSettings?.direction == .vertical)
            #expect(job.layout == CompositeLayoutResolver.layout(from: combine))
            #expect(job.layout == .vertical)
        }
    }

    @Test
    func `watermarkEnabled true_false — 각각 실제 settings 와 nil 주입`() {
        let appSettings = Self.makeAppSettings()
        let watermark = WatermarkSettings(type: .text, text: "PAIRSHOT", opacity: 0.7)
        appSettings.watermarkSettings = watermark
        let pair = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-id",
            afterPhotoLocalIdentifier: "after-id",
        )
        let selection = ExportContents(includeCombined: true, includeBefore: false, includeAfter: false)

        appSettings.watermarkEnabled = true
        let withWatermark = ExportJobBuilder.makeJobs(
            pairs: [pair],
            selection: selection,
            appSettings: appSettings,
            renderOptions: ExportRenderOptions(applyCombineSettings: false, isPro: true),
            now: Self.fixedDate,
        )
        #expect(!withWatermark.isEmpty)
        for job in withWatermark {
            #expect(job.watermark?.text == "PAIRSHOT")
            #expect(job.watermark?.opacity == 0.7)
        }

        appSettings.watermarkEnabled = false
        let withoutWatermark = ExportJobBuilder.makeJobs(
            pairs: [pair],
            selection: selection,
            appSettings: appSettings,
            renderOptions: ExportRenderOptions(applyCombineSettings: false, isPro: true),
            now: Self.fixedDate,
        )
        for job in withoutWatermark {
            #expect(job.watermark == nil)
        }
    }

    @Test
    func `pair → entries flatMap — selection 의 includeBefore_after 분기와 결합되어 정확히 펼쳐짐`() {
        let appSettings = Self.makeAppSettings()
        let pair1 = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-1",
            afterPhotoLocalIdentifier: "after-1",
        )
        let pair2 = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: "before-2",
            afterPhotoLocalIdentifier: "after-2",
        )

        let jobs = ExportJobBuilder.makeJobs(
            pairs: [pair1, pair2],
            selection: ExportContents(includeCombined: true, includeBefore: true, includeAfter: true),
            appSettings: appSettings,
            renderOptions: ExportRenderOptions(applyCombineSettings: false, isPro: true),
            now: Self.fixedDate,
        )

        #expect(jobs.count == 6)
        let pair1Jobs = jobs.filter { $0.pairId == pair1.id }
        let pair2Jobs = jobs.filter { $0.pairId == pair2.id }
        #expect(pair1Jobs.count == 3)
        #expect(pair2Jobs.count == 3)
        let kindsPair1 = Set(pair1Jobs.map(\.entry.kind))
        #expect(kindsPair1 == Set([.combined, .before, .after]))

        let beforeOnly = ExportJobBuilder.makeJobs(
            pairs: [pair1, pair2],
            selection: ExportContents(includeCombined: false, includeBefore: true, includeAfter: false),
            appSettings: appSettings,
            renderOptions: ExportRenderOptions(applyCombineSettings: false, isPro: true),
            now: Self.fixedDate,
        )
        #expect(beforeOnly.count == 2)
        #expect(beforeOnly.allSatisfy { $0.entry.kind == .before })
    }

    private static func makeAppSettings() -> AppSettings {
        let suiteName = "export-jobbuilder-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }
}
