import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PairPreviewViewModel {
    enum Event {
        case dismiss
    }

    let pair: PhotoPair

    var livePreviewImage: UIImage?
    var isRendering: Bool = false
    var zoomScale: CGFloat = 1.0
    var pinchBaseScale: CGFloat = 1.0
    var showDeleteConfirm: Bool = false
    var showShareSheet: Bool = false
    var showRetake: Bool = false
    var errorMessage: String?

    let events: AsyncStream<Event>

    private let storage: PhotoStorageService
    private let deletePairs: DeletePairsUseCase
    private let eventsContinuation: AsyncStream<Event>.Continuation

    static let minZoom: CGFloat = 1.0
    static let maxZoom: CGFloat = 4.0

    init(
        pair: PhotoPair,
        storage: PhotoStorageService,
        deletePairs: DeletePairsUseCase
    ) {
        self.pair = pair
        self.storage = storage
        self.deletePairs = deletePairs
        var continuation: AsyncStream<Event>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    var hasCombined: Bool {
        guard let name = pair.combinedFileName, !name.isEmpty else { return false }
        return true
    }

    var shareItems: [Any] {
        if let combinedURL = combinedURL() {
            return [combinedURL]
        }
        return resolvePairURLs()
    }

    func loadPreview() async {
        guard livePreviewImage == nil else { return }
        isRendering = true
        defer { isRendering = false }
        let resolved = await Self.loadCombinedImage(for: pair, storage: storage)
        livePreviewImage = resolved
    }

    func onShareTapped() {
        guard !shareItems.isEmpty else {
            errorMessage = String(localized: "공유할 사진을 찾을 수 없습니다")
            return
        }
        showShareSheet = true
    }

    func onRetakeTapped() {
        showRetake = true
    }

    func onDeleteTapped() {
        showDeleteConfirm = true
    }

    func confirmDelete() async {
        do {
            try await deletePairs(ids: [pair.id], mode: .wholePair)
            eventsContinuation.yield(.dismiss)
        } catch {
            errorMessage = String(localized: "페어 삭제에 실패했습니다")
        }
    }

    func dismiss() {
        eventsContinuation.yield(.dismiss)
    }

    func onPinchChanged(_ value: CGFloat) {
        let target = pinchBaseScale * value
        zoomScale = clamp(target)
    }

    func onPinchEnded(_ value: CGFloat) {
        pinchBaseScale = clamp(pinchBaseScale * value)
        zoomScale = pinchBaseScale
    }

    func resetZoom() {
        zoomScale = 1.0
        pinchBaseScale = 1.0
    }

    func clearError() {
        errorMessage = nil
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        max(Self.minZoom, min(Self.maxZoom, value))
    }

    private func combinedURL() -> URL? {
        guard let name = pair.combinedFileName, !name.isEmpty else { return nil }
        guard let url = storage.resolveCombined(fileName: name) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func resolvePairURLs() -> [URL] {
        var urls: [URL] = []
        if let url = storage.resolveBefore(fileName: pair.beforeFileName),
           FileManager.default.fileExists(atPath: url.path)
        {
            urls.append(url)
        }
        if let after = pair.afterFileName,
           let url = storage.resolveAfter(fileName: after),
           FileManager.default.fileExists(atPath: url.path)
        {
            urls.append(url)
        }
        return urls
    }

    static func loadCombinedImage(
        for pair: PhotoPair,
        storage: PhotoStorageService
    ) async -> UIImage? {
        guard let name = pair.combinedFileName, !name.isEmpty else { return nil }
        guard let url = storage.resolveCombined(fileName: name) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }

    deinit {}
}
