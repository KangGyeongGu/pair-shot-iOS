import AVFoundation
import SwiftUI

struct CameraControlBar: View {
    @Binding var flashMode: AVCaptureDevice.FlashMode
    @Binding var aspectRatio: AspectRatio
    @Binding var isGridEnabled: Bool
    @Binding var timerDuration: TimerDuration

    var onFlashTap: () -> Void
    var onRatioTap: () -> Void
    var onGridTap: () -> Void
    var onTimerTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    MenuGridButton(
                        symbol: flashSymbol,
                        label: flashLabel,
                        tint: flashTint,
                        isActive: flashMode != .off,
                        action: onFlashTap
                    )
                    MenuGridButton(
                        symbol: "grid",
                        label: "격자",
                        tint: isGridEnabled ? .yellow : .white,
                        isActive: isGridEnabled,
                        action: onGridTap
                    )
                    MenuGridButton(
                        symbol: "timer",
                        label: timerDuration == .off ? "타이머" : timerDuration.displayName,
                        tint: timerDuration != .off ? .yellow : .white,
                        isActive: timerDuration != .off,
                        action: onTimerTap
                    )
                }
                HStack(spacing: 0) {
                    MenuGridButton(
                        symbol: "rectangle.ratio.3.to.4",
                        label: aspectRatio.displayName,
                        tint: .white,
                        isActive: false,
                        action: onRatioTap
                    )
                    MenuGridButton(
                        symbol: "camera.filters",
                        label: "스타일",
                        tint: .white.opacity(0.4),
                        isActive: false,
                        action: {}
                    )
                    MenuGridButton(
                        symbol: "sun.max",
                        label: "노출",
                        tint: .white.opacity(0.4),
                        isActive: false,
                        action: {}
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var flashSymbol: String {
        switch flashMode {
            case .auto: return "bolt.badge.automatic.fill"
            case .on: return "bolt.fill"
            case .off: return "bolt.slash.fill"
            @unknown default: return "bolt.fill"
        }
    }

    private var flashLabel: String {
        switch flashMode {
            case .auto: return "자동"
            case .on: return "켜짐"
            case .off: return "꺼짐"
            @unknown default: return "자동"
        }
    }

    private var flashTint: Color {
        switch flashMode {
            case .on: .yellow
            case .off: .white.opacity(0.4)
            default: .white
        }
    }
}

private struct MenuGridButton: View {
    let symbol: String
    let label: String
    let tint: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            CameraControlBar(
                flashMode: .constant(.auto),
                aspectRatio: .constant(.ratio4_3),
                isGridEnabled: .constant(false),
                timerDuration: .constant(.off),
                onFlashTap: {},
                onRatioTap: {},
                onGridTap: {},
                onTimerTap: {}
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
}
