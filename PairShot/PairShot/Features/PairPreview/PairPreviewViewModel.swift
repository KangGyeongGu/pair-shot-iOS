import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PairPreviewViewModel {
    static let minZoom: CGFloat = 1.0
    static let maxZoom: CGFloat = 4.0

    let pair: PhotoPair

    var livePreviewImage: UIImage?
    var isRendering: Bool = false
    var zoomScale: CGFloat = 1.0
    var pinchBaseScale: CGFloat = 1.0
    var panOffset: CGSize = .zero
    var panBaseOffset: CGSize = .zero
    var containerSize: CGSize = .zero
    var errorMessage: String?

    private let photoLibrary: PhotoLibraryService
    private let appSettings: AppSettings
    private let membership: Membership?

    init(
        pair: PhotoPair,
        photoLibrary: PhotoLibraryService,
        appSettings: AppSettings,
        membership: Membership? = nil,
    ) {
        self.pair = pair
        self.photoLibrary = photoLibrary
        self.appSettings = appSettings
        self.membership = membership
    }

    func loadPreview() async {
        guard livePreviewImage == nil else { return }
        guard pair.beforePhotoLocalIdentifier?.isEmpty == false else { return }
        guard pair.afterPhotoLocalIdentifier?.isEmpty == false else { return }
        isRendering = true
        defer { isRendering = false }
        do {
            let isPro = membership?.proIsActive ?? false
            let watermark: WatermarkSettings? =
                appSettings.watermarkEnabled
                    ? appSettings.watermarkSettings.effective(isPro: isPro)
                    : nil
            let combineSettings = appSettings.combineSettings.effective(isPro: isPro)
            let layout = CompositeLayoutResolver.layout(from: combineSettings)
            let quality = appSettings.exportQuality
            let options = CompositeOptions(
                layout: layout,
                compressionQuality: quality.compressionQuality,
                utType: quality.utType,
                watermarkEnabled: watermark != nil,
                watermark: watermark,
                combineSettings: combineSettings,
                includeGPS: appSettings.embedGPSInPhoto,
            )
            let data = try await CompositeRenderer.makeComposite(
                for: pair,
                photoLibrary: photoLibrary,
                options: options,
                now: .now,
            )
            livePreviewImage = UIImage(data: data)
        } catch {
            errorMessage = String(localized: "pair_preview_share_no_photo")
        }
    }

    func updateContainerSize(_ size: CGSize) {
        containerSize = size
        panOffset = clampOffset(panOffset, scale: zoomScale)
        panBaseOffset = clampOffset(panBaseOffset, scale: pinchBaseScale)
    }

    func onPinchChanged(_ value: CGFloat, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        let oldScale = pinchBaseScale
        let newScale = clamp(oldScale * value)
        zoomScale = newScale
        panOffset = clampOffset(
            offsetAfterScaling(from: oldScale, to: newScale, anchor: anchor),
            scale: newScale,
        )
    }

    func onPinchEnded(_ value: CGFloat, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        onPinchChanged(value, anchor: anchor)
        pinchBaseScale = zoomScale
        panBaseOffset = panOffset
    }

    func onDragChanged(translation: CGSize) {
        let candidate = CGSize(
            width: panBaseOffset.width + translation.width,
            height: panBaseOffset.height + translation.height,
        )
        panOffset = clampOffset(candidate, scale: zoomScale)
    }

    func onDragEnded(translation: CGSize) {
        onDragChanged(translation: translation)
        panBaseOffset = panOffset
    }

    func resetZoom() {
        zoomScale = 1.0
        pinchBaseScale = 1.0
        panOffset = .zero
        panBaseOffset = .zero
    }

    func clearError() {
        errorMessage = nil
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        max(Self.minZoom, min(Self.maxZoom, value))
    }

    private func clampOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let maxX = max(0, (scale - 1) * containerSize.width / 2)
        let maxY = max(0, (scale - 1) * containerSize.height / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY),
        )
    }

    private func offsetAfterScaling(
        from oldScale: CGFloat,
        to newScale: CGFloat,
        anchor: CGPoint,
    ) -> CGSize {
        guard containerSize.width > 0, containerSize.height > 0, oldScale > 0 else {
            return panBaseOffset
        }
        let anchorPoint = CGPoint(
            x: anchor.x * containerSize.width,
            y: anchor.y * containerSize.height,
        )
        let frameCenter = CGPoint(
            x: containerSize.width / 2,
            y: containerSize.height / 2,
        )
        let imagePoint = CGPoint(
            x: (anchorPoint.x - frameCenter.x - panBaseOffset.width) / oldScale,
            y: (anchorPoint.y - frameCenter.y - panBaseOffset.height) / oldScale,
        )
        return CGSize(
            width: panBaseOffset.width + (oldScale - newScale) * imagePoint.x,
            height: panBaseOffset.height + (oldScale - newScale) * imagePoint.y,
        )
    }
}
