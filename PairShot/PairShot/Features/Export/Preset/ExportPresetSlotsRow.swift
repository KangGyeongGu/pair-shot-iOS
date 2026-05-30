import SwiftUI

struct ExportPresetSlotsRow: View {
    let presets: [ExportPreset?]
    let activeIndex: Int
    let isProUser: Bool
    let onTap: (Int) -> Void
    let onLongPress: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< ExportPresetStore.maxSlots, id: \.self) { index in
                slotCell(at: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func slotCell(at index: Int) -> some View {
        let locked = !isProUser && index >= ExportPresetStore.freeAccessibleSlotCount
        let preset = presets[index]
        let active = index == activeIndex && preset != nil

        Button {
            onTap(index)
        } label: {
            slotContent(preset: preset, locked: locked, active: active, index: index)
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                onLongPress(index)
            },
        )
        .frame(maxWidth: .infinity)
        .background(slotAnchorOverlay(index: index))
    }

    @ViewBuilder
    private func slotAnchorOverlay(index: Int) -> some View {
        if index == 0 {
            Color.clear.anchorPreference(
                key: ExportPresetSlotZeroAnchorKey.self,
                value: .bounds,
            ) { $0 }
        }
    }

    @ViewBuilder
    private func slotContent(preset: ExportPreset?, locked: Bool, active: Bool, index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(spacing: 6) {
            iconArea(preset: preset, locked: locked, active: active, index: index)
            labelArea(preset: preset, locked: locked)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background {
            if active {
                shape.fill(Color.accentColor.opacity(0.18))
            } else {
                Color.clear
            }
        }
        .overlay {
            if preset == nil {
                shape.strokeBorder(
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]),
                )
                .foregroundStyle(Color.secondary.opacity(0.5))
            } else {
                shape.strokeBorder(
                    active ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: active ? 1.5 : 1,
                )
            }
        }
        .contentShape(shape)
    }

    @ViewBuilder
    private func iconArea(preset: ExportPreset?, locked: Bool, active _: Bool, index _: Int) -> some View {
        if locked {
            Image(systemName: "lock.fill")
                .font(.body)
                .foregroundStyle(.secondary)
        } else if preset == nil {
            Image(systemName: "plus")
                .font(.body)
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func labelArea(preset: ExportPreset?, locked: Bool) -> some View {
        if let preset {
            Text(preset.name)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
        } else if locked {
            Text(String(localized: "export_preset_slot_locked"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Color.clear.frame(height: 0)
        }
    }
}
