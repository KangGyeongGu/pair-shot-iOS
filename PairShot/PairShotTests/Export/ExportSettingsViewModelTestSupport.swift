import Foundation
@testable import PairShot

@MainActor
enum ExportSettingsViewModelTestSupport {
    static func makeViewModel(
        format: ExportFormat = .individualImages,
        pairIds: [UUID] = [UUID()],
        withPresetStore: Bool = false,
    ) -> ExportSettingsViewModel {
        let suiteName = "test-export-state-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let appSettings = AppSettings(defaults: defaults)
        let preferences = ExportPreferences(defaults: defaults)
        preferences.format = format
        let presetStore: ExportPresetStore? = withPresetStore
            ? ExportPresetStore(
                appSettings: appSettings,
                preferences: preferences,
                defaults: defaults,
            )
            : nil
        return ExportSettingsViewModel(
            pairIds: pairIds,
            pairRepo: ExportSettingsStubPhotoPairRepository(),
            photoLibrary: PhotoLibraryService(),
            exportPairs: ExportPairsUseCase(
                zipExporter: ZipExporterAdapter(
                    photoLibrary: PhotoLibraryService(),
                    pairRepo: ExportSettingsStubPhotoPairRepository(),
                    appSettings: appSettings,
                ),
            ),
            photoLibraryExporter: PhotoLibraryExport(),
            snackbarQueue: SnackbarQueue(),
            appSettings: appSettings,
            preferences: preferences,
            membership: nil,
            exportPresetStore: presetStore,
        )
    }
}

final class ExportSettingsStubPhotoPairRepository: PhotoPairRepository, @unchecked Sendable {
    func fetchAll(tutorialOnly _: Bool) async throws -> [PhotoPair] {
        []
    }

    func fetch(id _: UUID) async throws -> PhotoPair? {
        nil
    }

    func fetch(ids _: [UUID]) async throws -> [PhotoPair] {
        []
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
