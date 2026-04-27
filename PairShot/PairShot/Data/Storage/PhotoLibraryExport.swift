import Foundation
import OSLog
import Photos

protocol PhotoLibraryExporting: Sendable {
    func authorize() async -> PHAuthorizationStatus
    func saveImageData(_ data: Data, type: ImageMediaType) async throws
}

enum ImageMediaType {
    case photo
}

enum PhotoLibraryExportError: Error, Equatable {
    case notAuthorized
    case writeFailed(String)
}

final class PhotoLibraryExport: PhotoLibraryExporting {
    init() {}

    func authorize() async -> PHAuthorizationStatus {
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

    func saveImageData(_ data: Data, type: ImageMediaType) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .authorized || status == .limited else {
            AppLogger.storage.error("PhotoLibraryExport not authorized")
            throw PhotoLibraryExportError.notAuthorized
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    let resourceType: PHAssetResourceType = switch type {
                        case .photo: .photo
                    }
                    request.addResource(with: resourceType, data: data, options: nil)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else if let error {
                        continuation.resume(throwing: PhotoLibraryExportError.writeFailed(
                            String(describing: error)
                        ))
                    } else {
                        continuation.resume(throwing: PhotoLibraryExportError.writeFailed("unknown"))
                    }
                }
            }
        } catch {
            AppLogger.storage.error(
                "PhotoLibraryExport saveImageData failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
        AppLogger.storage.info("PhotoLibraryExport saveImageData success")
    }
}
