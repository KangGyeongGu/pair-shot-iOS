import Foundation

@MainActor
final class RecaptureAfterUseCase {
    let pairRepo: PhotoPairRepository
    let photoLibrary: PhotoLibraryService
    let captureAfter: CaptureAfterUseCase

    init(
        pairRepo: PhotoPairRepository,
        photoLibrary: PhotoLibraryService,
        captureAfter: CaptureAfterUseCase
    ) {
        self.pairRepo = pairRepo
        self.photoLibrary = photoLibrary
        self.captureAfter = captureAfter
    }

    func callAsFunction(
        pairId: UUID,
        afterJPEG: Data
    ) async throws -> PhotoPair {
        guard let pair = try await pairRepo.fetch(id: pairId) else {
            throw CaptureAfterUseCase.CaptureAfterError.pairNotFound
        }
        var staleAssetIds: [String] = []
        if let oldAfter = pair.afterPhotoLocalIdentifier, !oldAfter.isEmpty {
            staleAssetIds.append(oldAfter)
        }
        let combinedIds = try await pairRepo.combinedExportPhotoIdentifiers(forPairIds: [pairId])
        staleAssetIds.append(contentsOf: combinedIds)

        let updated = try await captureAfter(pairId: pairId, afterJPEG: afterJPEG)

        try await photoLibrary.deleteAssets(localIdentifiers: staleAssetIds)
        try await pairRepo.deleteCombinedExportRecords(forPairIds: [pairId])
        return updated
    }
}
