import Foundation
import SwiftData
import SwiftUI
import UIKit

enum AfterCaptureActionError: Error {
    case session(CameraSessionError)
    case storage(Error)
    case persistence(Error)
    case alreadyComplete
}

struct AfterCaptureOutcome {
    let completedPair: PhotoPair
    let nextPendingPair: PhotoPair?
}

struct AfterCaptureCoordinator {
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
    func captureAfter(
        for pair: PhotoPair,
        into context: ModelContext,
        pendingScope: [PhotoPair] = []
    ) async throws -> AfterCaptureOutcome {
        guard pair.afterFileName == nil else {
            throw AfterCaptureActionError.alreadyComplete
        }

        let captured: CapturedPhoto
        do {
            captured = try await session.capturePhoto()
        } catch let err as CameraSessionError {
            throw AfterCaptureActionError.session(err)
        } catch {
            throw AfterCaptureActionError.session(.captureFailed(error.localizedDescription))
        }

        let normalizedJPEG = await ExifNormalizationTask.normalize(
            data: captured.jpegData,
            jpegQuality: jpegQuality
        )

        let fileName = FileNameBuilder.after(
            prefix: fileNamePrefix,
            timestamp: captured.capturedAt,
            pairId: pair.id
        )

        do {
            _ = try storage.saveAfterJPEG(normalizedJPEG, fileName: fileName)
        } catch {
            throw AfterCaptureActionError.storage(error)
        }

        pair.afterFileName = fileName
        pair.afterCapturedAt = captured.capturedAt
        pair.updatedAt = .now
        for album in pair.albums {
            album.updatedAt = .now
        }

        do {
            try context.save()
        } catch {
            throw AfterCaptureActionError.persistence(error)
        }

        let next = AfterCameraPairLoader.nextPendingPair(after: pair, in: pendingScope)
        return AfterCaptureOutcome(completedPair: pair, nextPendingPair: next)
    }
}

enum AfterCameraPairLoader {
    static func pendingPairs(in pairs: [PhotoPair]) -> [PhotoPair] {
        pairs
            .filter { $0.afterFileName == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func firstPendingPair(in pairs: [PhotoPair]) -> PhotoPair? {
        pendingPairs(in: pairs).first
    }

    static func nextPendingPair(after current: PhotoPair, in pairs: [PhotoPair]) -> PhotoPair? {
        pairs
            .filter { $0.id != current.id && $0.afterFileName == nil }
            .min { $0.createdAt < $1.createdAt }
    }
}

struct AfterCameraScopeFetch {
    let pairRepo: PhotoPairRepository
    let albumId: UUID?

    func fetch() async -> AfterCameraScopeSnapshot {
        let fetched = try? await pairRepo.fetchAll()
        let all = fetched ?? []
        let scoped: [PhotoPair] = if let albumId {
            all.filter { pair in pair.albums.contains(where: { $0.id == albumId }) }
        } else {
            all
        }
        let pending = AfterCameraPairLoader.pendingPairs(in: scoped)
        let completed = scoped.count(where: { $0.afterFileName != nil })
        return AfterCameraScopeSnapshot(pending: pending, completedCount: completed)
    }
}

struct AfterCameraScopeSnapshot {
    let pending: [PhotoPair]
    let completedCount: Int
}

enum AfterCameraInitialPairResolver {
    static func resolve(initialPairId: UUID?, pending: [PhotoPair]) -> PhotoPair? {
        if let id = initialPairId, let match = pending.first(where: { $0.id == id }) {
            return match
        }
        return pending.first
    }
}
