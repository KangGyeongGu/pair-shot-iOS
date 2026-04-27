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
    let pairRepo: PhotoPairRepository?
    let fileNamePrefix: String
    let jpegQuality: CGFloat

    init(
        session: CameraSession,
        storage: PhotoStorageService,
        pairRepo: PhotoPairRepository? = nil,
        fileNamePrefix: String = "",
        jpegQuality: CGFloat = ExifNormalizer.defaultJPEGQuality
    ) {
        self.session = session
        self.storage = storage
        self.pairRepo = pairRepo
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
        let sequenceNumber: Int = if let pairRepo {
            await (try? pairRepo.nextSequenceNumber()) ?? PairSequenceResolver.fallback(in: context)
        } else {
            PairSequenceResolver.fallback(in: context)
        }
        let fileName = FileNameBuilder.before(
            prefix: fileNamePrefix,
            timestamp: captured.capturedAt,
            sequenceNumber: sequenceNumber
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

enum PairSequenceResolver {
    static func fallback(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<PhotoPair>()
        let all = (try? context.fetch(descriptor)) ?? []
        let maxSeq = all
            .compactMap { FileNameBuilder.extractSequenceNumber(from: $0.beforeFileName) }
            .max() ?? 0
        return maxSeq + 1
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
