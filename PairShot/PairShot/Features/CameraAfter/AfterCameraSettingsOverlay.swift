import SwiftUI

struct AfterCameraSettingsOverlay: View {
    @Binding var isPresented: Bool
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
        CameraSettingsOverlayChrome(isPresented: $isPresented) {
            VStack(spacing: 16) {
                chipRow
                if overlayEnabled {
                    Divider().background(Color.white.opacity(0.18))
                    CameraSettingsOverlayAlphaSlider(alpha: alpha, onChange: onAlphaChange)
                }
            }
        }
    }

    private var chipRow: some View {
        LazyVGrid(
            columns: CameraSettingsOverlayLayout.gridColumns,
            spacing: CameraSettingsOverlayMetrics.chipSpacing
        ) {
            CameraSettingsOverlayChip(
                systemImage: "square.grid.3x3",
                isOn: isGridOn,
                label: String(localized: "camera_settings_grid"),
                action: onToggleGrid
            )
            CameraSettingsOverlayChip(
                systemImage: FlashChipPresentation.iconName(for: flashMode),
                isOn: FlashChipPresentation.isActive(flashMode),
                label: String(localized: "camera_settings_section_flash"),
                action: onCycleFlash
            )
            CameraSettingsOverlayChip(
                systemImage: "moon.fill",
                isOn: isNightModeOn,
                label: String(localized: "camera_settings_night_mode"),
                action: onToggleNightMode
            )
            CameraSettingsOverlayChip(
                systemImage: "level",
                isOn: isLevelOn,
                label: String(localized: "camera_settings_level"),
                action: onToggleLevel
            )
            CameraSettingsOverlayChip(
                systemImage: "circle.lefthalf.filled",
                isOn: overlayEnabled,
                label: String(localized: "camera_settings_section_overlay"),
                action: onToggleOverlay
            )
        }
        .frame(maxWidth: .infinity)
    }
}
