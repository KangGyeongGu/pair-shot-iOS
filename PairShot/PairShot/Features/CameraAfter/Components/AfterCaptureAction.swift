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

@MainActor
struct AfterCaptureCoordinator {
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
    func captureAfter(
        for pair: PhotoPair,
        into context: ModelContext,
        pendingScope: [PhotoPair] = []
    ) async throws -> AfterCaptureOutcome {
        guard pair.afterPhotoLocalIdentifier == nil else {
            throw AfterCaptureActionError.alreadyComplete
        }

        let pairId = pair.id
        let descriptor = FetchDescriptor<PhotoPairEntity>(
            predicate: #Predicate { $0.id == pairId }
        )
        guard let entity = try? context.fetch(descriptor).first else {
            throw AfterCaptureActionError.persistence(
                NSError(domain: "PairShot.AfterCapture", code: -1)
            )
        }

        let captured: CapturedPhoto
        do {
            captured = try await session.capturePhoto()
        } catch let err as CameraSessionError {
            throw AfterCaptureActionError.session(err)
        } catch {
            throw AfterCaptureActionError.session(.captureFailed(error.localizedDescription))
        }

        let localIdentifier: String
        do {
            localIdentifier = try await photoLibrary.saveImage(captured.jpegData)
        } catch {
            throw AfterCaptureActionError.storage(error)
        }

        entity.afterPhotoLocalIdentifier = localIdentifier
        entity.afterCapturedAt = captured.capturedAt
        entity.updatedAt = .now
        for album in entity.albums {
            album.updatedAt = .now
        }

        do {
            try context.save()
        } catch {
            throw AfterCaptureActionError.persistence(error)
        }

        let completed = entity.toDomain()
        let next = AfterCameraPairLoader.nextPendingPair(after: completed, in: pendingScope)
        return AfterCaptureOutcome(completedPair: completed, nextPendingPair: next)
    }
}

enum AfterCameraPairLoader {
    static func pendingPairs(in pairs: [PhotoPair], sortOrder: HomeSortOrder = .newest) -> [PhotoPair] {
        let pending = pairs.filter { $0.afterPhotoLocalIdentifier == nil }
        return sort(pending, sortOrder: sortOrder)
    }

    static func firstPendingPair(in pairs: [PhotoPair], sortOrder: HomeSortOrder = .newest) -> PhotoPair? {
        pendingPairs(in: pairs, sortOrder: sortOrder).first
    }

    static func nextPendingPair(
        after current: PhotoPair,
        in pairs: [PhotoPair],
        sortOrder: HomeSortOrder = .newest
    ) -> PhotoPair? {
        let remaining = pairs.filter { $0.id != current.id && $0.afterPhotoLocalIdentifier == nil }
        return sort(remaining, sortOrder: sortOrder).first
    }

    private static func sort(_ pairs: [PhotoPair], sortOrder: HomeSortOrder) -> [PhotoPair] {
        switch sortOrder {
            case .newest:
                pairs.sorted { $0.createdAt > $1.createdAt }

            case .oldest:
                pairs.sorted { $0.createdAt < $1.createdAt }
        }
    }
}

struct AfterCameraScopeFetch {
    let pairRepo: PhotoPairRepository
    let albumId: UUID?

    func fetch(
        initialPairId: UUID? = nil,
        sortOrder: HomeSortOrder = .newest,
        calendar: Calendar = .current
    ) async -> AfterCameraScopeSnapshot {
        let fetched = try? await pairRepo.fetchAll()
        let all = fetched ?? []
        let albumScoped: [PhotoPair] = if let albumId {
            all.filter { $0.albumIds.contains(albumId) }
        } else {
            all
        }
        let pending = albumScoped.filter { $0.afterPhotoLocalIdentifier == nil }
        let dayScoped: [PhotoPair]
        if let initialPairId,
           let initialPair = albumScoped.first(where: { $0.id == initialPairId })
        {
            let day = calendar.startOfDay(for: initialPair.createdAt)
            dayScoped = pending.filter {
                calendar.startOfDay(for: $0.createdAt) == day
            }
        } else {
            dayScoped = pending
        }
        let sorted = AfterCameraPairLoader.pendingPairs(in: dayScoped, sortOrder: sortOrder)
        let completed = albumScoped.count(where: { $0.afterPhotoLocalIdentifier != nil })
        return AfterCameraScopeSnapshot(pending: sorted, completedCount: completed)
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
