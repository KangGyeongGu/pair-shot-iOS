import Foundation
import Photos

/// P7.2 — write captured / composited JPEGs back into the user's Photos app.
///
/// **Permission model**: we only ever *add* assets, never read existing ones,
/// so we request `.addOnly` rather than `.readWrite`. This keeps PairShot
/// outside the "limited library" prompt path and matches the
/// `NSPhotoLibraryAddUsageDescription` Info.plist key (no
/// `NSPhotoLibraryUsageDescription`).
///
/// The protocol exists so `ExportPicker`'s save-to-library flow can be unit
/// tested without standing up a real `PHPhotoLibrary` (which the Simulator
/// can stub but XCTest cannot drive deterministically). Production wiring
/// uses `PhotoLibraryExport`; tests use a `FakePhotoLibraryExporter`.
protocol PhotoLibraryExporting: Sendable {
    /// Drive the system permission prompt if needed and return the resulting
    /// status. Caller decides whether to continue or surface the Settings
    /// deep-link (P10.4 polish — for now `ExportPicker` shows an error toast).
    func authorize() async -> PHAuthorizationStatus

    /// Persist a single JPEG into the user's library as a new asset.
    /// - Throws: `PhotoLibraryExportError` on permission denial or PHKit
    ///   change-block failure.
    func saveImageData(_ data: Data, type: ImageMediaType) async throws
}

/// Discriminator for future expansion (videos, raws); today only `.photo` is
/// emitted by the export picker. Kept as an enum so we don't have to change
/// the protocol when P11+ adds RAW capture.
enum ImageMediaType {
    case photo
}

/// Errors surfaced from `PhotoLibraryExport` to the caller.
enum PhotoLibraryExportError: Error, Equatable {
    /// User denied or restricted Photos add-only access. UI should offer a
    /// "Settings" button via `UIApplication.openSettingsURLString`.
    case notAuthorized
    /// `PHPhotoLibrary.performChanges` reported a non-success completion.
    /// Wrapped error string is for log inspection only — UI shows a generic
    /// retry message.
    case writeFailed(String)
}

/// Production `PhotoLibraryExporting`. Thin wrapper over `PHPhotoLibrary` —
/// no caching, no batching. Each call request reauthorization and submits a
/// fresh `performChanges` block, which is acceptable for the export picker's
/// "save N items" loop because PHKit serializes changes internally.
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
        let status = await authorize()
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryExportError.notAuthorized
        }
        // `performChanges(_:completionHandler:)` is the documented async-bridge
        // surface for PHKit on iOS 17+. The closure is *non*-throwing; failure
        // is reported via the `(Bool, Error?)` completion pair.
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
    }
}
