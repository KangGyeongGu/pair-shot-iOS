import SwiftUI

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
            alignment: .center
        ),
    ]
}

struct BeforeCameraSettingsOverlay: View {
    @Binding var isPresented: Bool
    let isGridOn: Bool
    let isLevelOn: Bool
    let isNightModeOn: Bool
    let flashMode: CameraFlashMode
    let onToggleGrid: () -> Void
    let onToggleLevel: () -> Void
    let onToggleNightMode: () -> Void
    let onCycleFlash: () -> Void

    var body: some View {
        CameraSettingsOverlayChrome(isPresented: $isPresented) {
            chipRow
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
        }
        .frame(maxWidth: .infinity)
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
            onToggleGrid: {},
            onToggleLevel: {},
            onToggleNightMode: {},
            onCycleFlash: {}
        )
    }
}
