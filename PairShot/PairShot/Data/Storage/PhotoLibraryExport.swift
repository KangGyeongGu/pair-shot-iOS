import Foundation
import OSLog
import Photos

enum ImageMediaType {
    case photo
}

enum PhotoLibraryExportError: Error, Equatable {
    case notAuthorized
    case writeFailed(String)
}

final class PhotoLibraryExport: Sendable {
    init() {}

    nonisolated func authorize() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
            case .authorized, .limited:
                return current

            case .denied, .restricted:
                return current

            case .notDetermined:
                return await PHPhotoLibrary.requestAuthorization(for: .addOnly)

            @unknown default:
                return current
        }
    }

    @discardableResult
    nonisolated func saveImageData(_ data: Data, type: ImageMediaType) async throws -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .authorized || status == .limited else {
            AppLogger.storage.error("PhotoLibraryExport not authorized")
            throw PhotoLibraryExportError.notAuthorized
        }
        do {
            let identifier: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
                String,
                Error
            >) in
                let placeholderBox = PlaceholderBox()
                let resourceType: PHAssetResourceType = switch type {
                    case .photo: .photo
                }
                let changesBlock: @Sendable () -> Void = {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: resourceType, data: data, options: nil)
                    placeholderBox.placeholder = request.placeholderForCreatedAsset
                }
                let completionBlock: @Sendable (Bool, Error?) -> Void = { success, error in
                    if success, let id = placeholderBox.placeholder?.localIdentifier {
                        continuation.resume(returning: id)
                    } else if let error {
                        continuation.resume(throwing: PhotoLibraryExportError.writeFailed(
                            String(describing: error)
                        ))
                    } else {
                        continuation.resume(throwing: PhotoLibraryExportError.writeFailed("unknown"))
                    }
                }
                PHPhotoLibrary.shared().performChanges(changesBlock, completionHandler: completionBlock)
            }
            AppLogger.storage.info("PhotoLibraryExport saveImageData success")
            return identifier
        } catch {
            AppLogger.storage.error(
                "PhotoLibraryExport saveImageData failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }
}

private final nonisolated class PlaceholderBox: @unchecked Sendable {
    var placeholder: PHObjectPlaceholder?
}
