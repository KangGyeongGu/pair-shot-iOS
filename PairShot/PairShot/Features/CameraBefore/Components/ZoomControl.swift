import SwiftUI

struct ZoomControl: View {
    let presets: [ZoomPresetSpec]
    let displayMultiplier: Double
    let activePreset: ZoomPresetSpec?
    let isDragging: Bool
    let currentRatio: Double
    let minRatio: Double
    let maxRatio: Double
    let onSelect: (ZoomPresetSpec) -> Void
    let onDragChanged: (Double) -> Void
    let onDragEnded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if presets.isEmpty {
            EmptyView()
        } else {
            ZStack {
                if isDragging {
                    ZoomDialOverlay(
                        currentRatio: currentRatio,
                        minRatio: minRatio,
                        maxRatio: maxRatio,
                        displayMultiplier: displayMultiplier
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.lg)
                    .allowsHitTesting(false)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                } else {
                    presetCapsule
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isDragging)
        }
    }

    private var presetCapsule: some View {
        HStack(spacing: 6) {
            ForEach(presets) { preset in
                button(for: preset)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .adaptiveGlass(in: Capsule())
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                onDragChanged(Double(value.translation.width))
            }
            .onEnded { _ in
                onDragEnded()
            }
    }

    init(
        presets: [ZoomPresetSpec],
        displayMultiplier: Double,
        activePreset: ZoomPresetSpec?,
        isDragging: Bool = false,
        currentRatio: Double = 1.0,
        minRatio: Double = 1.0,
        maxRatio: Double = 1.0,
        onSelect: @escaping (ZoomPresetSpec) -> Void,
        onDragChanged: @escaping (Double) -> Void = { _ in },
        onDragEnded: @escaping () -> Void = {}
    ) {
        self.presets = presets
        self.displayMultiplier = displayMultiplier
        self.activePreset = activePreset
        self.isDragging = isDragging
        self.currentRatio = currentRatio
        self.minRatio = minRatio
        self.maxRatio = maxRatio
        self.onSelect = onSelect
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    @ViewBuilder
    private func button(for preset: ZoomPresetSpec) -> some View {
        let isActive = preset == activePreset
        let display = label(for: preset, isActive: isActive)
        let size: CGFloat = isActive ? 36 : 28
        Button {
            onSelect(preset)
        } label: {
            Text(display)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(isActive ? Color.black : Color.white.opacity(0.85))
                .frame(width: size, height: size)
                .background(
                    Circle().fill(isActive ? Color.accentColor : Color.clear)
                )
                .accessibilityLabel(display)
        }
        .buttonStyle(.plain)
    }

    private func label(for preset: ZoomPresetSpec, isActive: Bool) -> String {
        guard isActive else { return preset.label }
        if abs(preset.factor - currentRatio) < 0.05 { return preset.label }
        return ZoomPresetBuilder.formatLabel(currentRatio * displayMultiplier)
    }
}

#Preview {
    ZStack {
        Color.appOnSurfaceVariant
        ZoomControl(
            presets: [
                ZoomPresetSpec(id: "uw", factor: 0.5, label: "0.5x"),
                ZoomPresetSpec(id: "w", factor: 1.0, label: "1x"),
                ZoomPresetSpec(id: "2x", factor: 2.0, label: "2x"),
                ZoomPresetSpec(id: "tele", factor: 5.0, label: "5x"),
            ],
            displayMultiplier: 1.0,
            activePreset: ZoomPresetSpec(id: "w", factor: 1.0, label: "1x"),
            isDragging: false,
            currentRatio: 1.0,
            minRatio: 0.5,
            maxRatio: 5.0,
            onSelect: { _ in },
            onDragChanged: { _ in },
            onDragEnded: {}
        )
    }
}
