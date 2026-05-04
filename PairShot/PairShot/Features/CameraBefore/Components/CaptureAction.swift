import Foundation
import SwiftData
import SwiftUI
import UIKit

enum CaptureActionError: Error {
    case session(CameraSessionError)
    case storage(Error)
    case persistence(Error)
}

@MainActor
struct BeforeCaptureCoordinator {
    let session: CameraSession
    let photoLibrary: PhotoLibraryService
    let pairRepo: PhotoPairRepository?
    let jpegQuality: CGFloat

    init(
        session: CameraSession,
        photoLibrary: PhotoLibraryService,
        pairRepo: PhotoPairRepository? = nil,
        jpegQuality: CGFloat = ExifNormalizer.defaultJPEGQuality
    ) {
        self.session = session
        self.photoLibrary = photoLibrary
        self.pairRepo = pairRepo
        self.jpegQuality = jpegQuality
    }

    @discardableResult
    func captureBefore(
        albumId: UUID? = nil,
        into context: ModelContext,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationLabel: String? = nil
    ) async throws -> PhotoPair {
        let captured: CapturedPhoto
        do {
            captured = try await session.capturePhoto()
        } catch let err as CameraSessionError {
            throw CaptureActionError.session(err)
        } catch {
            throw CaptureActionError.session(.captureFailed(error.localizedDescription))
        }

        let pairId = UUID()
        let cameraSettings = CameraSettings(
            zoomFactor: captured.zoomFactor,
            lensPosition: LensPosition.resolve(identifier: captured.lensIdentifier),
            flashMode: .off,
            useGrid: false,
            useNightMode: false,
            captureAngleDegrees: captured.captureAngleDegrees
        )

        let localIdentifier: String
        do {
            localIdentifier = try await photoLibrary.saveImage(captured.jpegData)
        } catch {
            throw CaptureActionError.storage(error)
        }

        let entity = PhotoPairEntity(
            id: pairId,
            beforePhotoLocalIdentifier: localIdentifier,
            beforeZoomFactor: captured.zoomFactor,
            beforeLensIdentifier: captured.lensIdentifier,
            cameraSettings: cameraSettings,
            latitude: latitude,
            longitude: longitude,
            locationLabel: locationLabel,
            capturedAt: captured.capturedAt
        )
        context.insert(entity)

        if let albumId {
            let descriptor = FetchDescriptor<AlbumEntity>(
                predicate: #Predicate { $0.id == albumId }
            )
            if let album = try? context.fetch(descriptor).first {
                entity.albums.append(album)
                album.updatedAt = .now
            }
        }

        do {
            try context.save()
        } catch {
            throw CaptureActionError.persistence(error)
        }

        return entity.toDomain()
    }
}

@MainActor
enum CaptureHaptics {
    static func shutter(_ haptics: HapticService) async {
        haptics.impact(.heavy)
    }

    static func success(_ haptics: HapticService) {
        haptics.notify(.success)
    }
}

struct CaptureShutterButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                    .opacity(isCapturing ? 0.4 : 1.0)
                if isCapturing {
                    ProgressView().tint(.gray)
                }
            }
            .accessibilityLabel(String(localized: "camera_desc_capture"))
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }
}
