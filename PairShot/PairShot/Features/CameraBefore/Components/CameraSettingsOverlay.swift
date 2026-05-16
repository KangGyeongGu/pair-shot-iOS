import SwiftUI

enum FlashChipPresentation {
    static func iconName(for mode: CameraFlashMode) -> String {
        switch mode {
            case .off: "bolt.slash.fill"
            case .on: "bolt.fill"
            case .auto: "bolt.badge.a.fill"
            case .torch: "flashlight.on.fill"
        }
    }

    static func isActive(_ mode: CameraFlashMode) -> Bool {
        mode != .off
    }
}

enum CameraSettingsOverlayMetrics {
    static let panelMaxWidth: CGFloat = 420
    static let panelPadding: CGFloat = 24
    static let panelCornerRadius: CGFloat = 28
    static let chipSize: CGFloat = 56
    static let chipIconSize: CGFloat = 24
    static let chipSpacing: CGFloat = 14
    static let chipMinColumnWidth: CGFloat = 84
    static let dimOpacity: Double = 0.35
    static let chipLabelSpacing: CGFloat = 6
}

enum CameraSettingsOverlayLayout {
    static let gridColumns: [GridItem] = [
        GridItem(
            .adaptive(minimum: CameraSettingsOverlayMetrics.chipMinColumnWidth),
            spacing: CameraSettingsOverlayMetrics.chipSpacing,
            alignment: .center,
        ),
    ]
}

struct BeforeCameraSettingsOverlay: View {
    @Binding var isPresented: Bool
    let isGridOn: Bool
    let isLevelOn: Bool
    let isNightModeOn: Bool
    let flashMode: CameraFlashMode
    let aspect: AspectRatio
    let onToggleGrid: () -> Void
    let onToggleLevel: () -> Void
    let onToggleNightMode: () -> Void
    let onCycleFlash: () -> Void
    let onCycleAspect: () -> Void

    var body: some View {
        CameraSettingsOverlayChrome(isPresented: $isPresented) {
            chipRow
        }
    }

    private var chipRow: some View {
        LazyVGrid(
            columns: CameraSettingsOverlayLayout.gridColumns,
            spacing: CameraSettingsOverlayMetrics.chipSpacing,
        ) {
            CameraSettingsOverlayChip(
                systemImage: "square.grid.3x3",
                isOn: isGridOn,
                label: String(localized: "camera_settings_grid"),
                action: onToggleGrid,
            )
            CameraSettingsOverlayChip(
                systemImage: FlashChipPresentation.iconName(for: flashMode),
                isOn: FlashChipPresentation.isActive(flashMode),
                label: String(localized: "camera_settings_section_flash"),
                action: onCycleFlash,
            )
            CameraSettingsOverlayChip(
                systemImage: "moon.fill",
                isOn: isNightModeOn,
                label: String(localized: "camera_settings_night_mode"),
                action: onToggleNightMode,
            )
            CameraSettingsOverlayChip(
                systemImage: "level",
                isOn: isLevelOn,
                label: String(localized: "camera_settings_level"),
                action: onToggleLevel,
            )
            AspectRatioChip(
                aspect: aspect,
                action: onCycleAspect,
            )
        }
        .frame(maxWidth: .infinity)
    }
}

struct AspectRatioChip: View {
    @Environment(AppEnvironment.self) private var env

    let aspect: AspectRatio
    let action: () -> Void

    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: CameraSettingsOverlayMetrics.chipLabelSpacing) {
                Text(aspect.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.black)
                    .frame(
                        width: CameraSettingsOverlayMetrics.chipSize,
                        height: CameraSettingsOverlayMetrics.chipSize,
                    )
                    .background(
                        Circle().fill(Color.accentColor),
                    )

                Text(String(localized: "camera_settings_aspect_ratio"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "camera_settings_aspect_ratio"))
            .accessibilityValue(aspect.label)
            .accessibilityAddTraits(.isButton)
        }
        .buttonStyle(.plain)
    }

    private func handleTap() {
        env.hapticService.impact(.light)
        action()
    }
}

#Preview {
    ZStack {
        Color.appCameraBackground.ignoresSafeArea()
        BeforeCameraSettingsOverlay(
            isPresented: .constant(true),
            isGridOn: true,
            isLevelOn: false,
            isNightModeOn: false,
            flashMode: .auto,
            aspect: .fourThree,
            onToggleGrid: {},
            onToggleLevel: {},
            onToggleNightMode: {},
            onCycleFlash: {},
            onCycleAspect: {},
        )
    }
}
