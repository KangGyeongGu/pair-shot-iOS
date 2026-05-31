import SwiftUI

struct TextSizePickerView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                ForEach(AppTextSize.allCases) { size in
                    TextSizePickerRow(
                        size: size,
                        isSelected: viewModel.appSettings.appTextSize == size,
                    ) {
                        viewModel.setAppTextSize(size)
                    }
                }
            } footer: {
                Text(String(localized: "settings_text_size_footer"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings_item_text_size"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TextSizePickerRow: View {
    let size: AppTextSize
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(size.displayName)
                    .font(.body)
                    .dynamicTypeSize(size.dynamicTypeSize)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
