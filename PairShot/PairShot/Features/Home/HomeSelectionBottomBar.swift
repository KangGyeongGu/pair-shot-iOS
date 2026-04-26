import SwiftUI

struct HomePairSelectionBottomBar: View {
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

struct HomeAlbumSelectionBottomBar: View {
    let selectionCount: Int
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        PairShotActionBar(items: [
            PairShotActionItem(
                title: String(localized: "이름 수정"),
                systemImage: "pencil",
                isEnabled: selectionCount == 1,
                action: onRename
            ),
            PairShotActionItem(
                title: String(localized: "삭제"),
                systemImage: "trash",
                role: .destructive,
                isEnabled: selectionCount > 0,
                action: onDelete
            ),
        ])
    }
}
