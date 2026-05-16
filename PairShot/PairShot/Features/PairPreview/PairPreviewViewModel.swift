import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PairPreviewViewModel {
    enum Event {
        case dismiss
    }

    static let minZoom: CGFloat = 1.0
    static let maxZoom: CGFloat = 4.0

    let pair: PhotoPair

    var livePreviewImage: UIImage?
    var isRendering: Bool = false
    var zoomScale: CGFloat = 1.0
    var pinchBaseScale: CGFloat = 1.0
    var errorMessage: String?

    let events: AsyncStream<Event>

    private let photoLibrary: PhotoLibraryService
    private let appSettings: AppSettings
    private let membership: Membership?
    private let eventsContinuation: AsyncStream<Event>.Continuation

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
        let stream = AsyncStream<Event>.makeStream()
        events = stream.stream
        eventsContinuation = stream.continuation
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
            let options = CompositeOptions(
                layout: layout,
                jpegQuality: 0.95,
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
}
