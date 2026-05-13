@preconcurrency import AVFoundation
import Foundation

nonisolated extension CameraSession {
    func setAspectRatio(_ ratio: AspectRatio) async {
        let session = box.session
        await runOnSessionQueueVoid { [weak self] in
            guard let self else { return }
            guard currentAspectRatio != ratio else { return }
            currentAspectRatio = ratio
            guard let output = photoOutput else { return }
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            applyDeferredDeliveryPolicy(on: output, for: ratio)
        }
    }

    private func applyDeferredDeliveryPolicy(
        on output: AVCapturePhotoOutput,
        for ratio: AspectRatio
    ) {
        let supportsDeferred = output.isAutoDeferredPhotoDeliverySupported
        let shouldEnableDeferred = ratio == .fourThree && supportsDeferred
        guard output.isAutoDeferredPhotoDeliveryEnabled != shouldEnableDeferred else { return }
        output.isAutoDeferredPhotoDeliveryEnabled = shouldEnableDeferred
    }
}
