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

private enum CameraSettingsOverlayLayout {
    static let gridColumns: [GridItem] = [
        GridItem(
            .adaptive(minimum: CameraSettingsOverlayMetrics.chipMinColumnWidth),
            spacing: CameraSettingsOverlayMetrics.chipSpacing,
            alignment: .center
        ),
    ]
}

private struct OverlayChip: View {
    let systemImage: String
    let isOn: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: CameraSettingsOverlayMetrics.chipLabelSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: CameraSettingsOverlayMetrics.chipIconSize, weight: .semibold))
                    .foregroundStyle(isOn ? Color.black : Color.white)
                    .frame(
                        width: CameraSettingsOverlayMetrics.chipSize,
                        height: CameraSettingsOverlayMetrics.chipSize
                    )
                    .background(
                        Circle().fill(isOn ? Color.appBrandPrimary : Color.white.opacity(0.18))
                    )

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
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

private struct OverlayAlphaSlider: View {
    let alpha: Double
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(String(localized: "camera_settings_overlay_opacity"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer(minLength: 0)
                Text(percentText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.white)
            }
            Slider(
                value: Binding(
                    get: { GhostOverlayMath.clamp(alpha) },
                    set: { onChange(GhostOverlayMath.clamp($0)) }
                ),
                in: GhostOverlayMath.alphaRange
            )
            .tint(Color.appBrandPrimary)
            .accessibilityLabel(String(localized: "camera_settings_overlay_opacity"))
            if alpha > 0.75 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(String(localized: "camera_settings_overlay_opacity_hint"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "camera_settings_overlay_opacity_hint"))
            }
        }
    }

    private var percentText: String {
        "\(Int((GhostOverlayMath.clamp(alpha) * 100).rounded()))%"
    }
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
            OverlayChip(
                systemImage: "square.grid.3x3",
                isOn: isGridOn,
                label: String(localized: "camera_settings_grid"),
                action: onToggleGrid
            )
            OverlayChip(
                systemImage: FlashChipPresentation.iconName(for: flashMode),
                isOn: FlashChipPresentation.isActive(flashMode),
                label: String(localized: "camera_settings_section_flash"),
                action: onCycleFlash
            )
            OverlayChip(
                systemImage: "moon.fill",
                isOn: isNightModeOn,
                label: String(localized: "camera_settings_night_mode"),
                action: onToggleNightMode
            )
            OverlayChip(
                systemImage: "level",
                isOn: isLevelOn,
                label: String(localized: "camera_settings_level"),
                action: onToggleLevel
            )
        }
        .frame(maxWidth: .infinity)
    }
}

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
                    OverlayAlphaSlider(alpha: alpha, onChange: onAlphaChange)
                }
            }
        }
    }

    private var chipRow: some View {
        LazyVGrid(
            columns: CameraSettingsOverlayLayout.gridColumns,
            spacing: CameraSettingsOverlayMetrics.chipSpacing
        ) {
            OverlayChip(
                systemImage: "square.grid.3x3",
                isOn: isGridOn,
                label: String(localized: "camera_settings_grid"),
                action: onToggleGrid
            )
            OverlayChip(
                systemImage: FlashChipPresentation.iconName(for: flashMode),
                isOn: FlashChipPresentation.isActive(flashMode),
                label: String(localized: "camera_settings_section_flash"),
                action: onCycleFlash
            )
            OverlayChip(
                systemImage: "moon.fill",
                isOn: isNightModeOn,
                label: String(localized: "camera_settings_night_mode"),
                action: onToggleNightMode
            )
            OverlayChip(
                systemImage: "level",
                isOn: isLevelOn,
                label: String(localized: "camera_settings_level"),
                action: onToggleLevel
            )
            OverlayChip(
                systemImage: "circle.lefthalf.filled",
                isOn: overlayEnabled,
                label: String(localized: "camera_settings_section_overlay"),
                action: onToggleOverlay
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CameraSettingsOverlayChrome<Content: View>: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(CameraSettingsOverlayMetrics.dimOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)

            panel
                .padding(.horizontal, AppSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
    }

    private var panel: some View {
        content
            .padding(CameraSettingsOverlayMetrics.panelPadding)
            .frame(maxWidth: CameraSettingsOverlayMetrics.panelMaxWidth)
            .appMaterialBackground(.panel)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: CameraSettingsOverlayMetrics.panelCornerRadius,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: CameraSettingsOverlayMetrics.panelCornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 24, y: 8)
            .accessibilityAddTraits(.isModal)
    }

    private func dismiss() {
        HapticService.shared.impact(.light)
        isPresented = false
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
