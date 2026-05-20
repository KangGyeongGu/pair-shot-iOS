import Foundation
@testable import PairShot
import Testing

@MainActor
struct ImmediateExportServiceSaveToDeviceTests {
    @Test
    func `saveToDevice individualImages 일 때 saveToPhotos progress 가 즉시 enqueue 된다`() async {
        let snackbar = SnackbarQueue()
        let service = Self.makeService(snackbarQueue: snackbar, format: .individualImages)
        let task = Task { @MainActor in
            _ = await service.saveToDevice(pairs: [Self.makeTestPair()])
        }
        await Self.yieldUntilProgressVisible(snackbar)
        let resolution = SnackbarReasonResolver.resolve(SnackbarProgressReason.saveToPhotos)
        let current = snackbar.current
        #expect(current?.title == resolution.title)
        #expect(current?.body == resolution.body)
        #expect(Self.isProgressVariant(current?.variant))
        task.cancel()
        await Self.awaitWithTimeout(task: task, seconds: 2.0)
    }

    @Test
    func `saveToDevice zip 일 때 prepareZipExport progress 가 즉시 enqueue 된다`() async {
        let snackbar = SnackbarQueue()
        let service = Self.makeService(snackbarQueue: snackbar, format: .zip)
        let task = Task { @MainActor in
            _ = await service.saveToDevice(pairs: [Self.makeTestPair()])
        }
        await Self.yieldUntilProgressVisible(snackbar)
        let resolution = SnackbarReasonResolver.resolve(SnackbarProgressReason.prepareZipExport)
        let current = snackbar.current
        #expect(current?.title == resolution.title)
        #expect(current?.body == resolution.body)
        #expect(Self.isProgressVariant(current?.variant))
        task.cancel()
        await Self.awaitWithTimeout(task: task, seconds: 2.0)
    }

    @Test
    func `finishZipExport saved true 는 savedZip 으로 completeProgress 한다`() {
        let snackbar = SnackbarQueue()
        let service = Self.makeService(snackbarQueue: snackbar, format: .zip)
        let handle = snackbar.enqueueProgress(
            .prepareZipExport,
            token: "zip-finish-saved",
            initialValue: 1.0,
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImmediateExportServiceSaveToDeviceTests-saved-\(UUID().uuidString).zip")
        try? Data([0x50, 0x4B, 0x05, 0x06]).write(to: tempURL)
        service.finishZipExport(url: tempURL, progress: handle, saved: true)
        let resolution = SnackbarReasonResolver.resolve(SnackbarReason.savedZip)
        #expect(snackbar.current?.title == resolution.title)
        #expect(snackbar.current?.body == resolution.body)
        #expect(snackbar.current?.token == nil)
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
    }

    @Test
    func `finishZipExport saved false 는 snackbar 표시 없이 cancelProgress 한다`() {
        let snackbar = SnackbarQueue()
        let service = Self.makeService(snackbarQueue: snackbar, format: .zip)
        let handle = snackbar.enqueueProgress(
            .prepareZipExport,
            token: "zip-finish-cancel",
            initialValue: 1.0,
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImmediateExportServiceSaveToDeviceTests-cancel-\(UUID().uuidString).zip")
        try? Data([0x50, 0x4B, 0x05, 0x06]).write(to: tempURL)
        service.finishZipExport(url: tempURL, progress: handle, saved: false)
        #expect(snackbar.current == nil)
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
    }

    private static func makeService(
        snackbarQueue: SnackbarQueue,
        format: ExportFormat,
    ) -> ImmediateExportService {
        let suiteName = "test-immediate-export-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let appSettings = AppSettings(defaults: defaults)
        let preferences = ExportPreferences(defaults: defaults)
        preferences.format = format
        preferences.includeBefore = true
        preferences.includeAfter = false
        preferences.includeCombined = false
        let photoLibrary = PhotoLibraryService()
        let pairRepo = StubPhotoPairRepositoryForImmediateExport()
        return ImmediateExportService(
            photoLibrary: photoLibrary,
            exportPairs: ExportPairsUseCase(
                zipExporter: ZipExporterAdapter(
                    photoLibrary: photoLibrary,
                    pairRepo: pairRepo,
                    appSettings: appSettings,
                ),
            ),
            photoLibraryExporter: PhotoLibraryExport(),
            snackbarQueue: snackbarQueue,
            appSettings: appSettings,
            pairRepo: pairRepo,
            membership: nil,
            preferences: preferences,
        )
    }

    private static func makeTestPair() -> PhotoPair {
        PhotoPair(
            id: UUID(),
            beforePhotoLocalIdentifier: "before-test",
            afterPhotoLocalIdentifier: "after-test",
        )
    }

    private static func isProgressVariant(_ variant: SnackbarVariant?) -> Bool {
        switch variant {
            case .progress, .indeterminateProgress: true
            default: false
        }
    }

    private static func yieldUntilProgressVisible(_ snackbar: SnackbarQueue, maxYields: Int = 32) async {
        for _ in 0 ..< maxYields {
            if isProgressVariant(snackbar.current?.variant) { return }
            await Task.yield()
        }
    }

    private static func awaitWithTimeout(task: Task<Void, Never>, seconds: TimeInterval) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = await task.value }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            _ = await group.next()
            group.cancelAll()
        }
    }
}

private final class StubPhotoPairRepositoryForImmediateExport: PhotoPairRepository, @unchecked Sendable {
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
