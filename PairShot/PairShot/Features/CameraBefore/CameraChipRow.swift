import SwiftUI

enum CameraChipMetrics {
    static let size: CGFloat = 36
    static let iconSize: CGFloat = 18
    static let spacing: CGFloat = 8
    static let inactiveBackground = Color.black.opacity(0.35)
}

struct CameraChip: View {
    let systemImage: String
    let isOn: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: systemImage)
                .font(.system(size: CameraChipMetrics.iconSize, weight: .semibold))
                .foregroundStyle(isOn ? Color.black : Color.white)
                .frame(width: CameraChipMetrics.size, height: CameraChipMetrics.size)
                .background(
                    Capsule().fill(isOn ? Color.appBrandPrimary : CameraChipMetrics.inactiveBackground)
                )
                .contentShape(Capsule())
                .accessibilityLabel(label)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        }
        .buttonStyle(.plain)
    }

    private func handleTap() {
        HapticService.shared.impact(.light)
        action()
    }
}

enum FlashChipPresentation {
    static func iconName(for mode: CameraFlashMode) -> String {
        switch mode {
            case .off:
                "bolt.slash.fill"

            case .on:
                "bolt.fill"

            case .auto:
                "bolt.badge.a.fill"

            case .torch:
                "flashlight.on.fill"
        }
    }

    static func isActive(_ mode: CameraFlashMode) -> Bool {
        mode != .off
    }
}

struct BeforeCameraChipRow: View {
    let isGridOn: Bool
    let isLevelOn: Bool
    let isNightModeOn: Bool
    let flashMode: CameraFlashMode
    let onToggleGrid: () -> Void
    let onToggleLevel: () -> Void
    let onToggleNightMode: () -> Void
    let onCycleFlash: () -> Void

    var body: some View {
        HStack(spacing: CameraChipMetrics.spacing) {
            Spacer(minLength: 0)
            CameraChip(
                systemImage: "square.grid.3x3",
                isOn: isGridOn,
                label: String(localized: "camera_settings_grid"),
                action: onToggleGrid
            )
            CameraChip(
                systemImage: FlashChipPresentation.iconName(for: flashMode),
                isOn: FlashChipPresentation.isActive(flashMode),
                label: String(localized: "camera_settings_section_flash"),
                action: onCycleFlash
            )
            CameraChip(
                systemImage: "moon.fill",
                isOn: isNightModeOn,
                label: String(localized: "camera_settings_night_mode"),
                action: onToggleNightMode
            )
            CameraChip(
                systemImage: "level",
                isOn: isLevelOn,
                label: String(localized: "camera_settings_level"),
                action: onToggleLevel
            )
        }
    }
}

struct AfterCameraChipRow: View {
    let isGridOn: Bool
    let isLevelOn: Bool
    let isNightModeOn: Bool
    let flashMode: CameraFlashMode
    let overlayEnabled: Bool
    let alpha: Double
    let onToggleGrid: () -> Void
    let onToggleLevel: () -> Void
    let onToggleNightMode: () -> Void
    let onCycleFlash: () -> Void
    let onToggleOverlay: () -> Void
    let onAlphaChange: (Double) -> Void

    var body: some View {
        HStack(spacing: CameraChipMetrics.spacing) {
            Spacer(minLength: 0)
            CameraChip(
                systemImage: "square.grid.3x3",
                isOn: isGridOn,
                label: String(localized: "camera_settings_grid"),
                action: onToggleGrid
            )
            CameraChip(
                systemImage: FlashChipPresentation.iconName(for: flashMode),
                isOn: FlashChipPresentation.isActive(flashMode),
                label: String(localized: "camera_settings_section_flash"),
                action: onCycleFlash
            )
            CameraChip(
                systemImage: "moon.fill",
                isOn: isNightModeOn,
                label: String(localized: "camera_settings_night_mode"),
                action: onToggleNightMode
            )
            CameraChip(
                systemImage: "level",
                isOn: isLevelOn,
                label: String(localized: "camera_settings_level"),
                action: onToggleLevel
            )
            CameraChip(
                systemImage: "circle.lefthalf.filled",
                isOn: overlayEnabled,
                label: String(localized: "camera_settings_section_overlay"),
                action: onToggleOverlay
            )
            if overlayEnabled {
                AlphaInlineSlider(alpha: alpha, onChange: onAlphaChange)
            }
        }
    }
}

struct AlphaInlineSlider: View {
    let alpha: Double
    let onChange: (Double) -> Void

    var body: some View {
        Slider(
            value: Binding(
                get: { GhostOverlayMath.clamp(alpha) },
                set: { onChange(GhostOverlayMath.clamp($0)) }
            ),
            in: GhostOverlayMath.alphaRange
        )
        .tint(Color.appBrandPrimary)
        .frame(width: 90, height: CameraChipMetrics.size)
        .padding(.horizontal, 6)
        .background(Capsule().fill(CameraChipMetrics.inactiveBackground))
        .accessibilityLabel(String(localized: "camera_settings_overlay_opacity"))
    }
}
