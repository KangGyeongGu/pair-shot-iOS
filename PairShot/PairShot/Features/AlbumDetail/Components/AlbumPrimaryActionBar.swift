import SwiftUI

struct AlbumEmptyActionBar: View {
    let onCapture: () -> Void
    let onPickPair: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onCapture) {
                Label(
                    String(localized: "common_button_start_capture"),
                    systemImage: "camera.fill"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Button(action: onPickPair) {
                Label(
                    String(localized: "album_button_add_pair"),
                    systemImage: "plus.rectangle.on.rectangle"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct AlbumDetailBottomBarHost: View {
    let viewModel: AlbumDetailViewModel
    let sortedPairs: [PhotoPair]
    let onPushExportSettings: (([UUID]) -> Void)?

    var body: some View {
        if viewModel.isSelectionMode {
            AlbumDetailSelectionBottomBar(
                selectionCount: viewModel.selectedPairIds.count,
                onShare: { Task { await viewModel.shareSelectedPairs(from: sortedPairs) } },
                onSaveToDevice: { Task { await viewModel.saveSelectedPairsToDevice(from: sortedPairs) } },
                onDelete: { viewModel.requestPairDeletion(from: sortedPairs) },
                onExportSettings: pushExport
            )
        } else {
            AlbumEmptyActionBar(
                onCapture: viewModel.startCapture,
                onPickPair: viewModel.startPairPicker
            )
        }
    }

    private func pushExport() {
        let chosen =
            sortedPairs
                .filter { viewModel.selectedPairIds.contains($0.id) }
                .map(\.id)
        guard !chosen.isEmpty else { return }
        onPushExportSettings?(chosen)
    }
}

struct AlbumDetailSelectionBottomBar: View {
    let selectionCount: Int
    let onShare: () -> Void
    let onSaveToDevice: () -> Void
    let onDelete: () -> Void
    let onExportSettings: () -> Void

    var body: some View {
        let enabled = selectionCount > 0
        PairShotActionBar(items: [
            PairShotActionItem(
                title: String(localized: "common_button_share"),
                systemImage: "square.and.arrow.up",
                isEnabled: enabled,
                action: onShare
            ),
            PairShotActionItem(
                title: String(localized: "common_button_save_to_device"),
                systemImage: "arrow.down.to.line",
                isEnabled: enabled,
                action: onSaveToDevice
            ),
            PairShotActionItem(
                title: String(localized: "common_button_delete"),
                systemImage: "trash",
                role: .destructive,
                isEnabled: enabled,
                action: onDelete
            ),
            PairShotActionItem(
                title: String(localized: "common_button_export"),
                systemImage: "slider.horizontal.3",
                isEnabled: enabled,
                action: onExportSettings
            ),
        ])
    }
}
