@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct QRScannerView: View {
    let onScan: (String) -> Void
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

    private func handleScan(_ payload: String) {
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

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context _: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = { payload in
            onScan(payload)
        }
        return controller
    }

    func updateUIViewController(_: QRScannerViewController, context _: Context) {}
}
