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

struct HomeAlbumSelectionBottomBar: View {
    let selectionCount: Int
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        PairShotActionBar(items: [
            PairShotActionItem(
                title: String(localized: "common_button_rename"),
                systemImage: "pencil",
                isEnabled: selectionCount == 1,
                action: onRename
            ),
            PairShotActionItem(
                title: String(localized: "common_button_delete"),
                systemImage: "trash",
                role: .destructive,
                isEnabled: selectionCount > 0,
                action: onDelete
            ),
        ])
    }
}
