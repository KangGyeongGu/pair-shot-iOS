import SwiftUI

/// Horizontal stack of zoom preset buttons (0.5x · 1x · 2x · 5x).
///
/// Buttons that aren't supported by the active device are hidden — never
/// disabled — so the user doesn't see a non-functional 0.5x on a single-lens
/// device. Selection is reflected by the active button's filled background.
struct ZoomControl: View {
    /// Currently active preset (or nil if user is between presets via pinch).
    let activePreset: ZoomPreset?

    /// Indicates which presets are selectable on the active device.
    /// Closure rather than a static set so the bar can react when lens changes.
    let isSupported: (ZoomPreset) -> Bool

    /// User tapped a preset.
    let onSelect: (ZoomPreset) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ZoomPreset.allCases, id: \.self) { preset in
                if isSupported(preset) {
                    button(for: preset)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    @ViewBuilder
    private func button(for preset: ZoomPreset) -> some View {
        let isActive = preset == activePreset
        Button {
            onSelect(preset)
        } label: {
            Text(preset.label)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(isActive ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Circle()
                        .fill(isActive ? Color.yellow : Color.clear)
                )
                .accessibilityLabel(preset.label)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray
        ZoomControl(
            activePreset: .wide,
            isSupported: { _ in true },
            onSelect: { _ in }
        )
    }
}
