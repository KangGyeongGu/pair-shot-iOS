import SwiftUI

struct SettingsWatermarkSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]
    @Environment(RewardedAdManager.self) private var rewardedManager

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseWatermark) {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.watermarkEnabled },
                        set: { viewModel.watermarkEnabled = $0 },
                    ),
                ) {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "signature", color: .blue),
                        )
                        Text(String(localized: "settings_item_watermark_use"))
                    }
                }
            }
            if viewModel.watermarkEnabled {
                Button {
                    if viewModel.requestWatermarkGate(rewardedManager: rewardedManager) {
                        path.append(.watermarkSettings)
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "slider.horizontal.3", color: .blue),
                        )
                        Text(String(localized: "settings_item_user_settings"))
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.watermarkSettingsBlank {
                            InlineWarningLabel(text: String(localized: "settings_warning_setup_needed"))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
            }
        } header: {
            Text(String(localized: "settings_section_watermark"))
        }
    }
}
