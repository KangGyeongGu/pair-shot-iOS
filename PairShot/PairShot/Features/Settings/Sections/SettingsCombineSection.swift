import SwiftUI

struct SettingsCombineSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Binding var path: [Route]
    @Environment(RewardedAdManager.self) private var rewardedManager

    var body: some View {
        Section {
            HighlightableCard(isHighlighted: viewModel.shouldPulseCombine) {
                Button {
                    if viewModel.requestCombineGate(rewardedManager: rewardedManager) {
                        path.append(.combineSettings)
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(
                            icon: SettingsRowIcon(systemImage: "square.on.square", color: .blue),
                        )
                        Text(String(localized: "settings_item_user_settings"))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
            }
        } header: {
            Text(String(localized: "settings_section_combine"))
        }
    }
}
