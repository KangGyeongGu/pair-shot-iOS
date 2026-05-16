import Foundation
@testable import PairShot
import Testing

@MainActor
struct ExportSettingsViewModelGateTests {
    @Test
    func `Free user with ZIP format triggers paywall on share`() async {
        let viewModel = Self.makeViewModel(format: .zip, watermarkEnabled: false)
        await viewModel.share()
        #expect(viewModel.showPaywall == true)
    }

    @Test
    func `Free user with ZIP format triggers paywall on save`() async {
        let viewModel = Self.makeViewModel(format: .zip, watermarkEnabled: false)
        await viewModel.saveToDevice()
        #expect(viewModel.showPaywall == true)
    }

    @Test
    func `Free user selectFormat zip triggers paywall and does not switch format`() {
        let viewModel = Self.makeViewModel(format: .individualImages, watermarkEnabled: false)
        viewModel.selectFormat(.zip)
        #expect(viewModel.showPaywall == true)
        #expect(viewModel.format == .individualImages)
    }

    @Test
    func `Watermark enabled but blank triggers snackbar on share`() async {
        let viewModel = Self.makeViewModel(
            format: .individualImages,
            watermarkEnabled: true,
            watermarkText: "",
        )
        await viewModel.share()
        let item = viewModel.snackbarQueue.current
        #expect(item != nil)
        if case .warning = item?.variant { } else {
            Issue.record("Expected warning variant, got \(String(describing: item?.variant))")
        }
    }

    @Test
    func `Watermark enabled with non-blank text proceeds past gate`() {
        let viewModel = Self.makeViewModel(
            format: .individualImages,
            watermarkEnabled: true,
            watermarkText: "Hello",
        )
        #expect(viewModel.ensureExportEligibility() == true)
    }

    @Test
    func `Watermark disabled bypasses watermark blank check`() {
        let viewModel = Self.makeViewModel(
            format: .individualImages,
            watermarkEnabled: false,
            watermarkText: "",
        )
        #expect(viewModel.ensureExportEligibility() == true)
    }

    @Test
    func `watermarkSettingsBlank reflects appSettings.watermarkSettings.isBlank`() {
        let viewModel = Self.makeViewModel(
            format: .individualImages,
            watermarkEnabled: true,
            watermarkText: "",
        )
        #expect(viewModel.watermarkSettingsBlank == true)
        viewModel.appSettings.watermarkSettings = WatermarkSettings(type: .text, text: "Brand")
        #expect(viewModel.watermarkSettingsBlank == false)
    }

    @Test
    func `applyWatermark setter mutates appSettings.watermarkEnabled (single source)`() {
        let viewModel = Self.makeViewModel(format: .individualImages, watermarkEnabled: false)
        viewModel.applyWatermark = true
        #expect(viewModel.appSettings.watermarkEnabled == true)
        viewModel.applyWatermark = false
        #expect(viewModel.appSettings.watermarkEnabled == false)
    }

    private static func makeViewModel(
        format: ExportFormat,
        watermarkEnabled: Bool,
        watermarkText: String = "",
    ) -> ExportSettingsViewModel {
        let suiteName = "test-export-gate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let appSettings = AppSettings(defaults: defaults)
        appSettings.watermarkEnabled = watermarkEnabled
        appSettings.watermarkSettings = WatermarkSettings(type: .text, text: watermarkText)
        let preferences = ExportPreferences(defaults: defaults)
        preferences.format = format
        return ExportSettingsViewModel(
            pairIds: [UUID()],
            pairRepo: StubPhotoPairRepository(),
            photoLibrary: PhotoLibraryService(),
            exportPairs: ExportPairsUseCase(
                zipExporter: ZipExporterAdapter(
                    photoLibrary: PhotoLibraryService(),
                    pairRepo: StubPhotoPairRepository(),
                    appSettings: appSettings,
                ),
            ),
            photoLibraryExporter: PhotoLibraryExport(),
            snackbarQueue: SnackbarQueue(),
            appSettings: appSettings,
            preferences: preferences,
            membership: nil,
        )
    }
}

private final class StubPhotoPairRepository: PhotoPairRepository, @unchecked Sendable {
    func fetchAll() async throws -> [PhotoPair] {
        []
    }

    func fetch(id _: UUID) async throws -> PhotoPair? {
        nil
    }

    func countCreated(since _: Date) async throws -> Int {
        0
    }

    func add(_: PhotoPair) async throws {}
    func update(_: PhotoPair) async throws {}
    func delete(ids _: Set<UUID>) async throws {}
    func deleteCombinedExportRecords(forPairIds _: Set<UUID>) async throws {}
    func combinedExportPhotoIdentifiers(forPairIds _: Set<UUID>) async throws -> [String] {
        []
    }

    func allExportPhotoIdentifiers(forPairIds _: Set<UUID>) async throws -> [String] {
        []
    }

    func recordExportHistory(pairId _: UUID, kind _: ExportHistoryKind, photoLocalIdentifier _: String) async throws {}
}
