import SwiftUI

struct HomeFilterRow: View {
    @Binding var contentMode: HomeContentMode
    @Binding var sortOrder: HomeSortOrder
    let onModeChange: (HomeContentMode) -> Void
    let onSortOrderChange: (HomeSortOrder) -> Void

    var body: some View {
        HStack(spacing: 12) {
            modePicker
                .frame(maxWidth: 220)
            Spacer()
            sortMenu
        }
    }

    private var modePicker: some View {
        Picker(String(localized: "common_view_label"), selection: $contentMode) {
            Text(String(localized: "home_filter_all")).tag(HomeContentMode.pairs)
            Text(String(localized: "home_filter_album")).tag(HomeContentMode.albums)
        }
        .pickerStyle(.segmented)
        .onChange(of: contentMode) { _, newValue in
            onModeChange(newValue)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker(String(localized: "common_sort_label"), selection: sortBinding) {
                Text(String(localized: "common_label_sort_descending")).tag(HomeSortOrder.newest)
                Text(String(localized: "common_label_sort_ascending")).tag(HomeSortOrder.oldest)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.headline)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "common_sort_label"))
    }

    private var sortBinding: Binding<HomeSortOrder> {
        Binding(
            get: { sortOrder },
            set: { newValue in
                sortOrder = newValue
                onSortOrderChange(newValue)
            }
        )
    }
}
