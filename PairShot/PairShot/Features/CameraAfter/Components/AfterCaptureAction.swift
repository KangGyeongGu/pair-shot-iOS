import Foundation
import SwiftData
import SwiftUI
import UIKit

enum AfterCameraPairLoader {
    static func pendingPairs(in pairs: [PhotoPair], sortOrder: HomeSortOrder = .newest) -> [PhotoPair] {
        let pending = pairs.filter { $0.afterPhotoLocalIdentifier == nil }
        return sort(pending, sortOrder: sortOrder)
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
        let albumScoped: [PhotoPair] =
            if let albumId {
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
