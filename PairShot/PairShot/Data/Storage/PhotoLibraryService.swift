import Foundation
import Photos
import UIKit
import UniformTypeIdentifiers

final nonisolated class PhotoLibraryService: Sendable {
    enum LibraryError: Error, Equatable {
        case notAuthorized
        case saveFailed(String)
        case deleteFailed(String)
    }

    private let tutorialPhotoStore: TutorialPhotoStore?

    init(tutorialPhotoStore: TutorialPhotoStore? = nil) {
        self.tutorialPhotoStore = tutorialPhotoStore
    }

    nonisolated func authorize(level: PHAccessLevel = .addOnly) async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: level)
        switch current {
            case .authorized, .limited:
                return current

            case .denied, .restricted:
                return current

            case .notDetermined:
                return await PHPhotoLibrary.requestAuthorization(for: level)

            @unknown default:
                return current
        }
    }

    @discardableResult
    nonisolated func saveImage(
        _ data: Data,
        utType: UTType,
        isDeferredProxy: Bool = false,
    ) async throws -> String {
        let status = await authorize(level: .addOnly)
        guard status == .authorized || status == .limited else {
            throw LibraryError.notAuthorized
        }
        let typeIdentifier = utType.identifier
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let placeholderBox = PhotoLibraryPlaceholderBox()
            let changesBlock: @Sendable () -> Void = {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                let resourceType: PHAssetResourceType = isDeferredProxy ? .photoProxy : .photo
                if !isDeferredProxy {
                    options.uniformTypeIdentifier = typeIdentifier
                }
                request.addResource(with: resourceType, data: data, options: options)
                placeholderBox.placeholder = request.placeholderForCreatedAsset
            }
            let completionBlock: @Sendable (Bool, Error?) -> Void = { success, error in
                if success, let id = placeholderBox.placeholder?.localIdentifier {
                    continuation.resume(returning: id)
                } else if let error {
                    continuation.resume(throwing: LibraryError.saveFailed(String(describing: error)))
                } else {
                    continuation.resume(throwing: LibraryError.saveFailed("unknown"))
                }
            }
            PHPhotoLibrary.shared().performChanges(changesBlock, completionHandler: completionBlock)
        }
    }

    nonisolated func fetchAsset(localIdentifier: String) -> PHAsset? {
        guard !localIdentifier.isEmpty else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    nonisolated func deleteAssets(localIdentifiers: [String]) async throws {
        let nonEmpty = localIdentifiers.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return }
        let tutorialIds = nonEmpty.filter(TutorialPhotoStore.isTutorialIdentifier)
        let ids = nonEmpty.filter { !TutorialPhotoStore.isTutorialIdentifier($0) }
        if !tutorialIds.isEmpty, let tutorialPhotoStore {
            try tutorialPhotoStore.delete(localIdentifiers: tutorialIds)
        }
        guard !ids.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var collected: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in collected.append(asset) }
        guard !collected.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let assetsBox = PhotoLibraryAssetsBox(value: assets)
            let changesBlock: @Sendable () -> Void = {
                PHAssetChangeRequest.deleteAssets(assetsBox.value)
            }
            let completionBlock: @Sendable (Bool, Error?) -> Void = { success, error in
                if success {
                    continuation.resume(returning: ())
                } else if let error {
                    continuation.resume(throwing: LibraryError.deleteFailed(String(describing: error)))
                } else {
                    continuation.resume(throwing: LibraryError.deleteFailed("unknown"))
                }
            }
            PHPhotoLibrary.shared().performChanges(changesBlock, completionHandler: completionBlock)
        }
    }

    nonisolated func requestImageData(
        for asset: PHAsset,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
    ) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            if let progressHandler {
                options.progressHandler = { progress, _, _, _ in
                    progressHandler(progress)
                }
            }
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options,
            ) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    nonisolated func requestImageData(
        localIdentifier: String,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
    ) async -> Data? {
        if TutorialPhotoStore.isTutorialIdentifier(localIdentifier) {
            return await tutorialPhotoStore?.loadData(localIdentifier: localIdentifier)
        }
        guard let asset = fetchAsset(localIdentifier: localIdentifier) else { return nil }
        return await requestImageData(for: asset, progressHandler: progressHandler)
    }

    nonisolated func requestPreviewImage(
        localIdentifier: String,
        targetSize: CGSize,
    ) async -> UIImage? {
        guard !localIdentifier.isEmpty else { return nil }
        if TutorialPhotoStore.isTutorialIdentifier(localIdentifier) {
            guard let data = await tutorialPhotoStore?.loadData(localIdentifier: localIdentifier)
            else { return nil }
            return UIImage(data: data)
        }
        guard let asset = fetchAsset(localIdentifier: localIdentifier) else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .exact
            options.isSynchronous = false
            let resumeBox = PhotoLibraryPreviewResumeBox()
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options,
            ) { result, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                guard !resumeBox.didResume else { return }
                resumeBox.didResume = true
                continuation.resume(returning: result)
            }
        }
    }
}

private final nonisolated class PhotoLibraryPreviewResumeBox: @unchecked Sendable {
    var didResume: Bool = false
}

private final nonisolated class PhotoLibraryPlaceholderBox: @unchecked Sendable {
    var placeholder: PHObjectPlaceholder?
}

private final nonisolated class PhotoLibraryAssetsBox: @unchecked Sendable {
    let value: PHFetchResult<PHAsset>
    init(value: PHFetchResult<PHAsset>) {
        self.value = value
    }
}

@MainActor
final class PhotoLibraryThumbnailCache {
    nonisolated static let defaultThumbnailPixelSize: CGFloat = 600

    private let cache: NSCache<NSString, UIImage>
    private let manager = PHCachingImageManager()
    private let failedKeys: NSCache<NSString, NSNumber>
    private let tutorialPhotoStore: TutorialPhotoStore?

    init(
        countLimit: Int = 256,
        totalCostLimit: Int = 64 * 1024 * 1024,
        tutorialPhotoStore: TutorialPhotoStore? = nil,
    ) {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.cache = cache
        let failed = NSCache<NSString, NSNumber>()
        failed.countLimit = 256
        failedKeys = failed
        self.tutorialPhotoStore = tutorialPhotoStore
    }

    func cached(localIdentifier: String, targetSize: CGSize) -> UIImage? {
        guard !localIdentifier.isEmpty else { return nil }
        return cache.object(forKey: cacheKey(localIdentifier, targetSize))
    }

    func cached(
        localIdentifier: String,
        pixelSize: CGFloat = PhotoLibraryThumbnailCache.defaultThumbnailPixelSize,
    ) -> UIImage? {
        cached(localIdentifier: localIdentifier, targetSize: CGSize(width: pixelSize, height: pixelSize))
    }

    func image(
        for localIdentifier: String,
        pixelSize: CGFloat = PhotoLibraryThumbnailCache.defaultThumbnailPixelSize,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
    ) async -> UIImage? {
        await image(
            for: localIdentifier,
            targetSize: CGSize(width: pixelSize, height: pixelSize),
            progressHandler: progressHandler,
        )
    }

    func image(
        for localIdentifier: String,
        targetSize: CGSize,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
    ) async -> UIImage? {
        guard !localIdentifier.isEmpty else { return nil }
        let key = cacheKey(localIdentifier, targetSize)
        if let hit = cache.object(forKey: key) { return hit }
        if failedKeys.object(forKey: key) != nil { return nil }
        if TutorialPhotoStore.isTutorialIdentifier(localIdentifier) {
            return await tutorialImage(for: localIdentifier, key: key)
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            failedKeys.setObject(NSNumber(value: 1), forKey: key)
            return nil
        }
        let image: UIImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            if let progressHandler {
                options.progressHandler = { progress, _, _, _ in
                    progressHandler(progress)
                }
            }
            var didResume = false
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options,
            ) { result, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: result)
            }
        }
        if let image {
            cache.setObject(image, forKey: key, cost: Self.estimatedByteCost(image))
        } else {
            failedKeys.setObject(NSNumber(value: 1), forKey: key)
        }
        return image
    }

    func evict(localIdentifier: String) {
        guard !localIdentifier.isEmpty else { return }
        cache.removeAllObjects()
        failedKeys.removeAllObjects()
    }

    private func tutorialImage(for localIdentifier: String, key: NSString) async -> UIImage? {
        guard let tutorialPhotoStore else {
            failedKeys.setObject(NSNumber(value: 1), forKey: key)
            return nil
        }
        guard let data = await tutorialPhotoStore.loadData(localIdentifier: localIdentifier),
              let image = UIImage(data: data)
        else {
            failedKeys.setObject(NSNumber(value: 1), forKey: key)
            return nil
        }
        cache.setObject(image, forKey: key, cost: Self.estimatedByteCost(image))
        return image
    }

    private func cacheKey(_ localIdentifier: String, _ targetSize: CGSize) -> NSString {
        "\(localIdentifier)@\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
    }

    static func estimatedByteCost(_ image: UIImage) -> Int {
        let scale = image.scale
        let width = Int(image.size.width * scale)
        let height = Int(image.size.height * scale)
        return max(0, width * height * 4)
    }
}
