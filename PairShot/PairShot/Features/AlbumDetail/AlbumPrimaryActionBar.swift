import SwiftUI

struct AlbumPrimaryActionBar: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}

struct AlbumEmptyActionBar: View {
    let onCapture: () -> Void
    let onPickPair: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onCapture) {
                Label(
                    String(localized: "촬영 시작"),
                    systemImage: "camera.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: onPickPair) {
                Label(
                    String(localized: "페어 추가"),
                    systemImage: "plus.rectangle.on.rectangle"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}

struct AlbumDetailBottomBarHost: View {
    let viewModel: AlbumDetailViewModel
    let sortedPairs: [PhotoPair]

    var body: some View {
        if viewModel.isSelectionMode {
            AlbumDetailSelectionBottomBar(
                selectionCount: viewModel.selectedPairIds.count,
                onShare: { viewModel.presentExport(from: sortedPairs) },
                onSaveToDevice: { viewModel.presentExport(from: sortedPairs) },
                onDelete: { viewModel.requestPairDeletion(from: sortedPairs) },
                onExportSettings: { viewModel.presentExport(from: sortedPairs) }
            )
        } else if sortedPairs.isEmpty {
            AlbumEmptyActionBar(
                onCapture: viewModel.startCapture,
                onPickPair: viewModel.startPairPicker
            )
        } else {
            AlbumPrimaryActionBar(
                title: String(localized: "촬영 시작"),
                systemImage: "camera.fill",
                action: viewModel.startCapture
            )
        }
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
                title: String(localized: "공유"),
                systemImage: "square.and.arrow.up",
                isEnabled: enabled,
                action: onShare
            ),
            PairShotActionItem(
                title: String(localized: "기기저장"),
                systemImage: "arrow.down.to.line",
                isEnabled: enabled,
                action: onSaveToDevice
            ),
            PairShotActionItem(
                title: String(localized: "삭제"),
                systemImage: "trash",
                role: .destructive,
                isEnabled: enabled,
                action: onDelete
            ),
            PairShotActionItem(
                title: String(localized: "내보내기"),
                systemImage: "slider.horizontal.3",
                isEnabled: enabled,
                action: onExportSettings
            ),
        ])
    }
}
