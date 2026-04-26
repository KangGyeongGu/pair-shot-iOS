import SwiftUI

struct ZoomControl: View {
    let activePreset: ZoomPreset?
    let isSupported: (ZoomPreset) -> Bool
    let isDragging: Bool
    let currentRatio: Double
    let minRatio: Double
    let maxRatio: Double
    let onSelect: (ZoomPreset) -> Void
    let onDragChanged: (Double) -> Void
    let onDragEnded: () -> Void

    init(
        activePreset: ZoomPreset?,
        isSupported: @escaping (ZoomPreset) -> Bool,
        isDragging: Bool = false,
        currentRatio: Double = 1.0,
        minRatio: Double = 1.0,
        maxRatio: Double = 1.0,
        onSelect: @escaping (ZoomPreset) -> Void,
        onDragChanged: @escaping (Double) -> Void = { _ in },
        onDragEnded: @escaping () -> Void = {}
    ) {
        self.activePreset = activePreset
        self.isSupported = isSupported
        self.isDragging = isDragging
        self.currentRatio = currentRatio
        self.minRatio = minRatio
        self.maxRatio = maxRatio
        self.onSelect = onSelect
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    var body: some View {
        ZStack {
            if isDragging {
                ZoomDialOverlay(
                    currentRatio: currentRatio,
                    minRatio: minRatio,
                    maxRatio: maxRatio
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                presetCapsule
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(height: 60)
        .animation(.easeOut(duration: 0.18), value: isDragging)
        .gesture(dragGesture)
    }

    private var presetCapsule: some View {
        HStack(spacing: 4) {
            ForEach(ZoomPreset.allCases, id: \.self) { preset in
                if isSupported(preset) {
                    button(for: preset)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                onDragChanged(Double(value.translation.width))
            }
            .onEnded { _ in
                onDragEnded()
            }
    }
}

#Preview {
    ZStack {
        Color.gray
        ZoomControl(
            activePreset: .wide,
            isSupported: { _ in true },
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
