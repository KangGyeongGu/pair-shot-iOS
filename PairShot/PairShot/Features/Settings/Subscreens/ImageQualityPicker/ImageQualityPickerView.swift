import SwiftUI

struct ImageQualityPickerView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(CaptureQualityPreset.allCases) { preset in
                    ImageQualityPickerRow(
                        preset: preset,
                        isSelected: viewModel.imageQualityPreset == preset
                    ) {
                        viewModel.setImageQuality(preset)
                        dismiss()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings_dialog_image_quality_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ImageQualityPickerRow: View {
    let preset: CaptureQualityPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.label)
                        .foregroundStyle(.primary)
                    Text(verbatim: "\(Int((preset.rawValue * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
