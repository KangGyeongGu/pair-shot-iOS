import SwiftUI

/// Top-strip controls that don't belong on the shutter row:
/// flash mode cycle · grid toggle · level toggle · lens flip.
///
/// Pure presentation — all side effects bubble up via closures so the parent
/// camera view drives the `CameraSession` actor.
struct CameraControlBar: View {
    let flashMode: CameraFlashMode
    let lensPosition: CameraLensPosition
    let isGridOn: Bool
    let isLevelOn: Bool

    let onCycleFlash: () -> Void
    let onToggleLens: () -> Void
    let onToggleGrid: () -> Void
    let onToggleLevel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            iconButton(
                systemName: flashIconName,
                label: flashAccessibilityLabel,
                isHighlighted: flashMode != .off,
                action: onCycleFlash
            )

            iconButton(
                systemName: "square.grid.3x3",
                label: String(localized: "그리드"),
                isHighlighted: isGridOn,
                action: onToggleGrid
            )

            iconButton(
                systemName: "level",
                label: String(localized: "수평계"),
                isHighlighted: isLevelOn,
                action: onToggleLevel
            )

            Spacer()

            iconButton(
                systemName: lensPosition == .back ? "camera.rotate" : "camera.rotate.fill",
                label: String(localized: "렌즈 전환"),
                isHighlighted: lensPosition == .front,
                action: onToggleLens
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var flashIconName: String {
        switch flashMode {
            case .off: "bolt.slash"
            case .on: "bolt.fill"
            case .auto: "bolt.badge.a.fill"
            case .torch: "flashlight.on.fill"
        }
    }

    private var flashAccessibilityLabel: String {
        switch flashMode {
            case .off: String(localized: "플래시 끔")
            case .on: String(localized: "플래시 켬")
            case .auto: String(localized: "플래시 자동")
            case .torch: String(localized: "플래시 토치")
        }
    }

    private func iconButton(
        systemName: String,
        label: String,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isHighlighted ? .yellow : .white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.black.opacity(isHighlighted ? 0.55 : 0.35))
                )
                .accessibilityLabel(label)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray
        VStack {
            CameraControlBar(
                flashMode: .auto,
                lensPosition: .back,
                isGridOn: true,
                isLevelOn: false,
                onCycleFlash: {},
                onToggleLens: {},
                onToggleGrid: {},
                onToggleLevel: {}
            )
            Spacer()
        }
    }
}
