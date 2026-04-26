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
        Picker(String(localized: "보기"), selection: $contentMode) {
            Text(String(localized: "전체")).tag(HomeContentMode.pairs)
            Text(String(localized: "앨범")).tag(HomeContentMode.albums)
        }
        .pickerStyle(.segmented)
        .onChange(of: contentMode) { _, newValue in
            onModeChange(newValue)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker(String(localized: "정렬"), selection: sortBinding) {
                Text(String(localized: "최신순")).tag(HomeSortOrder.newest)
                Text(String(localized: "오래된순")).tag(HomeSortOrder.oldest)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(String(localized: "정렬"))
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
