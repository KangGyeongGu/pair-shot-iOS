import SwiftUI

struct ImageQualityPickerView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(ExportQuality.allCases) { preset in
                    ImageQualityPickerRow(
                        preset: preset,
                        isSelected: viewModel.exportQualityPreset == preset,
                    ) {
                        viewModel.setExportQuality(preset)
                        dismiss()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings_dialog_export_quality_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ImageQualityPickerRow: View {
    let preset: ExportQuality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.label)
                        .foregroundStyle(.primary)
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

    private var subtitleText: String? {
        switch preset {
            case .lossless: String(localized: "image_quality_lossless_subtitle")
            case .low, .standard, .high: "\(Int((preset.compressionQuality * 100).rounded()))%"
        }
    }
}
