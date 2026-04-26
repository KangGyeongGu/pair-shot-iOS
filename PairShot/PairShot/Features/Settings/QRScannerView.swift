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
/// P10b — the AVFoundation controller and its
/// `UIViewControllerRepresentable` bridge live in
/// ``QRScannerViewController.swift`` so this file stays under the
/// 250-line cap.
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
                        // Audit-C — Dynamic-Type friendly close button.
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .imageScale(.large)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(20)
                    .frame(minWidth: 44, minHeight: 44)
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
            // Audit-C — Dynamic-Type friendly empty-state icon.
            Image(systemName: "camera.metering.unknown")
                .font(.largeTitle)
                .imageScale(.large)
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
        // P9.1 — routed through ``HapticService`` so the QR scan and
        // the subsequent registration emit the same `.success` notif.
        HapticService.shared.notify(.success)
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

/// `UIViewControllerRepresentable` wrapping ``QRScannerViewController``.
/// View-controller bridging (rather than a raw `UIView`) keeps the
/// metadata-output delegate's lifecycle pinned to a well-defined object.
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
