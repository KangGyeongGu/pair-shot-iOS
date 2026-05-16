import Foundation
import Photos
import UniformTypeIdentifiers

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
    nonisolated func saveImageData(
        _ data: Data,
        type: ImageMediaType,
        utType: UTType,
    ) async throws -> String {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryExportError.notAuthorized
        }
        let typeIdentifier = utType.identifier
        typealias StringContinuation = CheckedContinuation<String, Error>
        return try await withCheckedThrowingContinuation { (continuation: StringContinuation) in
            let placeholderBox = PlaceholderBox()
            let resourceType: PHAssetResourceType =
                switch type {
                    case .photo: .photo
                }
            let changesBlock: @Sendable () -> Void = {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = typeIdentifier
                request.addResource(with: resourceType, data: data, options: options)
                placeholderBox.placeholder = request.placeholderForCreatedAsset
            }
            let completionBlock: @Sendable (Bool, Error?) -> Void = { success, error in
                if success, let id = placeholderBox.placeholder?.localIdentifier {
                    continuation.resume(returning: id)
                } else if let error {
                    continuation.resume(
                        throwing: PhotoLibraryExportError.writeFailed(
                            String(describing: error),
                        ),
                    )
                } else {
                    continuation.resume(throwing: PhotoLibraryExportError.writeFailed("unknown"))
                }
            }
            PHPhotoLibrary.shared().performChanges(changesBlock, completionHandler: completionBlock)
        }
    }
}

private final nonisolated class PlaceholderBox: @unchecked Sendable {
    var placeholder: PHObjectPlaceholder?
}
