@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// P6.4 — single-shot QR scanner backed by `AVCaptureMetadataOutput`.
///
/// **Camera-session isolation**: this owns its own `AVCaptureSession`
/// instance, *not* the shared `CameraSession` actor used by Before/After
/// capture. The session lives only for the duration of this view; the
/// first successful scan stops it and reports the payload via `onScan`.
/// Reusing the photo-capture actor would risk torch/zoom state bleed
/// across feature boundaries.
///
/// Forbidden alternative: Vision/CoreML QR detection. AVFoundation's
/// metadata output is a first-class API and Apple-recommended for the
/// scanner use case.
struct QRScannerView: View {
    /// Callback invoked once on the first successful scan. The string is
    /// the raw decoded payload (not yet parsed by `QRPayloadParser`).
    let onScan: (String) -> Void
    /// User dismissed the scanner without scanning.
    let onCancel: () -> Void

    @State private var permissionState: PermissionState = .checking

    enum PermissionState: Equatable {
        case checking
        case granted
        case denied
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch permissionState {
                case .checking:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)

                case .granted:
                    scannerContent

                case .denied:
                    deniedView
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(20)
                    .accessibilityLabel(String(localized: "닫기"))
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await requestPermissionIfNeeded()
        }
    }

    // MARK: - Subviews

    private var scannerContent: some View {
        ZStack {
            QRScannerRepresentable(onScan: handleScan)
                .ignoresSafeArea()

            ScannerGuideOverlay()

            VStack {
                Spacer()
                    .frame(height: 80)
                Text(String(localized: "QR 코드를 사각형 안에 맞춰주세요"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.55)))
                Spacer()
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            Text(String(localized: "카메라 권한이 필요합니다"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(String(localized: "설정에서 카메라 사용을 허용해 주세요"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                openSettings()
            } label: {
                Text(String(localized: "설정으로 이동"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .foregroundStyle(.black)
            }
        }
    }

    // MARK: - Actions

    private func handleScan(_ payload: String) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onScan(payload)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestPermissionIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                permissionState = .granted

            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                permissionState = granted ? .granted : .denied

            case .denied, .restricted:
                permissionState = .denied

            @unknown default:
                permissionState = .denied
        }
    }
}

// MARK: - Guide overlay

/// Visual sighting box centred on screen so the user knows where to aim.
/// Pure SwiftUI — no AVFoundation reach-back.
private struct ScannerGuideOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height) * 0.65
            let frame = CGRect(
                x: (geometry.size.width - side) / 2,
                y: (geometry.size.height - side) / 2,
                width: side,
                height: side
            )
            ZStack {
                // Dim the area outside the guide.
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRoundedRect(
                        in: frame,
                        cornerSize: CGSize(width: 16, height: 16)
                    )
                }
                .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: side, height: side)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - AVFoundation bridge

/// `UIViewControllerRepresentable` wrapping a UIKit controller that owns
/// the `AVCaptureSession`. View-controller bridging (rather than a raw
/// `UIView`) keeps the metadata-output delegate's lifecycle pinned to a
/// well-defined object.
private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context _: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = { payload in
            onScan(payload)
        }
        return controller
    }

    func updateUIViewController(_: QRScannerViewController, context _: Context) {
        // No-op: scanner is single-shot; once the parent dismisses
        // `fullScreenCover`, the controller is torn down.
    }
}

/// Owns one `AVCaptureSession` plus an `AVCaptureMetadataOutput`. Stops
/// the session on the first successful scan so the camera and torch
/// release immediately.
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
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
