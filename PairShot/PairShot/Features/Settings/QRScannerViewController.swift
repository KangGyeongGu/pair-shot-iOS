@preconcurrency import AVFoundation
import UIKit

// P10b — extracted from `QRScannerView.swift` so the SwiftUI wrapper
// stays under the 250-line cap. The controller owns one
// `AVCaptureSession` plus an `AVCaptureMetadataOutput`. It stops the
// session on the first successful scan so the camera and torch
// release immediately.
//
// Lifecycle is pinned to the controller (not the SwiftUI representable)
// so the metadata-output delegate callback always fires on a live
// object even if the parent view's `@State` is rebuilt.

/// View controller wrapping the AVFoundation QR session.
///
/// Forbidden alternative: Vision/CoreML QR detection. AVFoundation's
/// metadata output is a first-class API and Apple-recommended for the
/// scanner use case.
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    /// Invoked once on the first successful scan. The string is the raw
    /// decoded payload (not yet parsed by `QRPayloadParser`).
    var onScan: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReportedScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            // Per Apple guidance, `startRunning()` blocks; hop off the
            // main thread to avoid hitching the presentation animation.
            let session = captureSession
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(input)
        else {
            // Simulator or device without back camera. Leave the preview
            // layer empty; the caller can still cancel out.
            return
        }
        captureSession.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else { return }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        // `availableMetadataObjectTypes` must be queried *after* the
        // output is wired, otherwise `.qr` isn't reported as available.
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard !hasReportedScan else { return }
        for object in metadataObjects {
            guard let readable = object as? AVMetadataMachineReadableCodeObject else { continue }
            guard readable.type == .qr else { continue }
            guard let payload = readable.stringValue, !payload.isEmpty else { continue }
            hasReportedScan = true
            captureSession.stopRunning()
            onScan?(payload)
            break
        }
    }
}
