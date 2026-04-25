@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI bridge for `AVCaptureVideoPreviewLayer`.
/// Owned by the camera feature; the underlying session is provided by `CameraSession`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        CameraPreviewView(session: session)
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Session reference is stable for the view's lifetime — no update needed.
    }
}

/// `UIView` whose backing layer is `AVCaptureVideoPreviewLayer`.
/// Using `layerClass` avoids creating a separate sublayer for the preview.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    /// Convenience cast to the typed preview layer.
    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        backgroundColor = .black
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
