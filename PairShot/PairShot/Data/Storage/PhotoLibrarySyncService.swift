import Foundation
import OSLog
import Photos
import SwiftData

@MainActor
final class PhotoLibrarySyncService: NSObject, PHPhotoLibraryChangeObserver {
    private let modelContainer: ModelContainer
    private let photoLibrary: PhotoLibraryService
    private let thumbnailCache: ThumbnailCache
    private let logger = Logger(subsystem: "com.pairshot.PairShot", category: "PhotoLibrarySync")

    private var isRegistered = false
    private var pauseDepth = 0
    private var revalidationTask: Task<Void, Never>?

    init(
        modelContainer: ModelContainer,
        photoLibrary: PhotoLibraryService,
        thumbnailCache: ThumbnailCache
    ) {
        self.modelContainer = modelContainer
        self.photoLibrary = photoLibrary
        self.thumbnailCache = thumbnailCache
        super.init()
    }

    func register() {
        guard !isRegistered else { return }
        PHPhotoLibrary.shared().register(self)
        isRegistered = true
    }

    func unregister() {
        guard isRegistered else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        isRegistered = false
    }

    func withObserverPaused<T>(
        _ body: () async throws -> T
    ) async rethrows -> T {
        pause()
        defer { resume() }
        return try await body()
    }

    private func pause() {
        pauseDepth += 1
        if pauseDepth == 1, isRegistered {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }

    private func resume() {
        pauseDepth = max(0, pauseDepth - 1)
        if pauseDepth == 0, isRegistered {
            PHPhotoLibrary.shared().register(self)
        }
    }

    func revalidate() async {
        revalidationTask?.cancel()
        let task = Task { @MainActor in
            await performRevalidation()
        }
        revalidationTask = task
        await task.value
    }

    nonisolated func photoLibraryDidChange(_: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.pauseDepth == 0 else { return }
            await self.revalidate()
        }
    }

    private func performRevalidation() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized else { return }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<PhotoPair>()
        let pairs: [PhotoPair]
        do {
            pairs = try context.fetch(descriptor)
        } catch {
            logger.error("revalidate fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard !pairs.isEmpty else { return }

        let identifiers = collectIdentifiers(from: pairs)
        guard !identifiers.isEmpty else { return }

        let alive = aliveIdentifiers(from: identifiers)

        var didMutate = false
        var pairsToDelete: [PhotoPair] = []
        for pair in pairs {
            let beforeMissing = pair.beforePhotoLocalIdentifier.flatMap { identifier -> String? in
                guard !identifier.isEmpty else { return nil }
                return alive.contains(identifier) ? nil : identifier
            }
            let afterMissing = pair.afterPhotoLocalIdentifier.flatMap { identifier -> String? in
                guard !identifier.isEmpty else { return nil }
                return alive.contains(identifier) ? nil : identifier
            }
            if let beforeMissing {
                pair.beforePhotoLocalIdentifier = nil
                thumbnailCache.evict(localIdentifier: beforeMissing)
                didMutate = true
            }
            if let afterMissing {
                pair.afterPhotoLocalIdentifier = nil
                thumbnailCache.evict(localIdentifier: afterMissing)
                didMutate = true
            }
            if pair.beforePhotoLocalIdentifier == nil, pair.afterPhotoLocalIdentifier == nil {
                pairsToDelete.append(pair)
            }
        }

        for pair in pairsToDelete {
            context.delete(pair)
            didMutate = true
        }

        guard didMutate else { return }
        do {
            try context.save()
        } catch {
            logger.error("revalidate save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func collectIdentifiers(from pairs: [PhotoPair]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for pair in pairs {
            if let id = pair.beforePhotoLocalIdentifier, !id.isEmpty, seen.insert(id).inserted {
                ordered.append(id)
            }
            if let id = pair.afterPhotoLocalIdentifier, !id.isEmpty, seen.insert(id).inserted {
                ordered.append(id)
            }
        }
        return ordered
    }

    private func aliveIdentifiers(from identifiers: [String]) -> Set<String> {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var alive: Set<String> = []
        assets.enumerateObjects { asset, _, _ in
            alive.insert(asset.localIdentifier)
        }
        return alive
    }
}
