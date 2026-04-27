import Foundation

@MainActor
final class CaptureAfterUseCase {
    enum CaptureAfterError: Error, Equatable {
        case pairNotFound
    }

    let pairRepo: PhotoPairRepository
    let storage: PhotoStoring
    let fileNameBuilder: FileNameBuilding
    let exifNormalizer: ExifNormalizing
    let compositor: (any CompositorService)?
    let backgroundTaskGuard: BackgroundTaskGuard?
    let onCompositeCompleted: (@MainActor () -> Void)?
    let onCompositeFailed: (@MainActor (Error) -> Void)?
    let now: @Sendable () -> Date

    init(
        pairRepo: PhotoPairRepository,
        storage: PhotoStoring,
        fileNameBuilder: FileNameBuilding,
        exifNormalizer: ExifNormalizing,
        compositor: (any CompositorService)? = nil,
        backgroundTaskGuard: BackgroundTaskGuard? = nil,
        onCompositeCompleted: (@MainActor () -> Void)? = nil,
        onCompositeFailed: (@MainActor (Error) -> Void)? = nil,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.pairRepo = pairRepo
        self.storage = storage
        self.fileNameBuilder = fileNameBuilder
        self.exifNormalizer = exifNormalizer
        self.compositor = compositor
        self.backgroundTaskGuard = backgroundTaskGuard
        self.onCompositeCompleted = onCompositeCompleted
        self.onCompositeFailed = onCompositeFailed
        self.now = now
    }

    func callAsFunction(
        pairId: UUID,
        afterJPEG: Data,
        prefix: String,
        jpegQuality: Double = AppSettingsSnapshot.defaultJpegQuality,
        compositeOptions: CompositeOptions? = nil
    ) async throws -> PhotoPair {
        guard let pair = try await pairRepo.fetch(id: pairId) else {
            throw CaptureAfterError.pairNotFound
        }
        let timestamp = now()
        let fileName = fileNameBuilder.after(prefix: prefix, timestamp: timestamp, pairId: pairId)
        let normalized = await exifNormalizer.normalize(afterJPEG, jpegQuality: jpegQuality)
        let savedName = try storage.saveAfterJPEG(normalized, fileName: fileName)
        pair.afterFileName = savedName
        pair.afterCapturedAt = timestamp
        pair.updatedAt = timestamp
        try await pairRepo.update(pair)
        triggerAutoComposite(for: pair, prefix: prefix, options: compositeOptions, capturedAt: timestamp)
        return pair
    }

    private func triggerAutoComposite(
        for pair: PhotoPair,
        prefix: String,
        options: CompositeOptions?,
        capturedAt: Date
    ) {
        guard let compositor, let options else { return }
        let pairId = pair.id
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if let backgroundTaskGuard {
                    try await backgroundTaskGuard.run("composite-\(pairId.uuidString)") {
                        try await self.runComposite(
                            pairId: pairId,
                            compositor: compositor,
                            options: options,
                            prefix: prefix,
                            capturedAt: capturedAt
                        )
                    }
                } else {
                    try await runComposite(
                        pairId: pairId,
                        compositor: compositor,
                        options: options,
                        prefix: prefix,
                        capturedAt: capturedAt
                    )
                }
                onCompositeCompleted?()
            } catch {
                onCompositeFailed?(error)
            }
        }
    }

    private func runComposite(
        pairId: UUID,
        compositor: any CompositorService,
        options: CompositeOptions,
        prefix: String,
        capturedAt: Date
    ) async throws {
        guard let pair = try await pairRepo.fetch(id: pairId) else {
            throw CaptureAfterError.pairNotFound
        }
        _ = try await compositor.makeComposite(
            for: pair,
            options: options,
            fileNamePrefix: prefix,
            now: capturedAt
        )
    }

    deinit {}
}
