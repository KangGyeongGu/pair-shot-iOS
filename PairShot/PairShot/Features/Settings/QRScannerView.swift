import SwiftUI
import UIKit

struct QRScannerView: View {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var permissionState: PermissionState = .checking

    enum PermissionState: Equatable {
        case checking
        case granted
        case denied
    }

    var body: some View {
        ZStack {
            Color.appCameraBackground.ignoresSafeArea()

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
                    .accessibilityLabel(String(localized: "common_button_close"))
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
                Text(String(localized: "coupon_qr_align_hint"))
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
            Text(String(localized: "permission_camera_title"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(String(localized: "permission_camera_message"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                openSettings()
            } label: {
                Text(String(localized: "permission_button_open_settings"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .foregroundStyle(.black)
            }
        }
    }

    private func handleScan(_ payload: String) {
        env.hapticService.notify(.success)
        onScan(payload)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestPermissionIfNeeded() async {
        let granted = await env.permissionStatusService.requestCameraAccessIfNeeded()
        permissionState = granted ? .granted : .denied
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
