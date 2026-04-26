import Foundation
import SwiftData
import SwiftUI
import UIKit

enum CaptureActionError: Error {
    case session(CameraSessionError)
    case storage(Error)
    case persistence(Error)
}

struct BeforeCaptureCoordinator {
    let session: CameraSession
    let storage: PhotoStorageService
    let fileNamePrefix: String
    let jpegQuality: CGFloat

    init(
        session: CameraSession,
        storage: PhotoStorageService,
        fileNamePrefix: String = "",
        jpegQuality: CGFloat = ExifNormalizer.defaultJPEGQuality
    ) {
        self.session = session
        self.storage = storage
        self.fileNamePrefix = fileNamePrefix
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

        let normalizedJPEG = await ExifNormalizationTask.normalize(
            data: captured.jpegData,
            jpegQuality: jpegQuality
        )

        let pairId = UUID()
        let cameraSettings = CameraSettings(
            zoomFactor: captured.zoomFactor,
            lensPosition: V1ToV2Migrator.lensPosition(for: captured.lensIdentifier),
            flashMode: .off,
            useGrid: false,
            useNightMode: false
        )
        let fileName = FileNameBuilder.before(
            prefix: fileNamePrefix,
            timestamp: captured.capturedAt,
            pairId: pairId
        )

        do {
            _ = try storage.saveBeforeJPEG(normalizedJPEG, fileName: fileName)
        } catch {
            throw CaptureActionError.storage(error)
        }

        let pair = PhotoPair(
            beforeFileName: fileName,
            cameraSettings: cameraSettings,
            latitude: latitude,
            longitude: longitude,
            locationLabel: locationLabel,
            capturedAt: captured.capturedAt
        )
        pair.id = pairId
        context.insert(pair)

        if let albumId {
            let descriptor = FetchDescriptor<Album>(
                predicate: #Predicate { $0.id == albumId }
            )
            if let album = try? context.fetch(descriptor).first {
                pair.albums.append(album)
                album.updatedAt = .now
            }
        }

        do {
            try context.save()
        } catch {
            throw CaptureActionError.persistence(error)
        }

        return pair
    }
}

@MainActor
enum CaptureHaptics {
    static func shutter() async {
        HapticService.shared.impact(.heavy)
    }

    static func success() {
        HapticService.shared.notify(.success)
    }
}

struct CaptureShutterButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .opacity(isCapturing ? 0.4 : 1.0)
            }
            .accessibilityLabel(String(localized: "촬영"))
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }
}
