import SwiftUI

struct SettingsHelpSection: View {
    @Binding var path: [Route]
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @AppStorage("tutorial.completed") private var tutorialCompleted = false
    @State private var showTutorialRestartDialog = false

    var body: some View {
        Section {
            Button {
                showTutorialRestartDialog = true
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "questionmark.circle", color: .blue),
                    )
                    Text(String(localized: "settings_item_tutorial_restart"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                openURL(SettingsExternalLinks.appStoreReview)
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(
                        icon: SettingsRowIcon(systemImage: "star.bubble", color: .yellow),
                    )
                    Text(String(localized: "settings_item_app_review"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "settings_section_help"))
        }
        .alert(
            String(localized: "settings_tutorial_restart_confirm_title"),
            isPresented: $showTutorialRestartDialog,
        ) {
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
            Button(String(localized: "common_button_confirm")) {
                restartTutorial()
            }
        } message: {
            Text(String(localized: "settings_tutorial_restart_confirm_message"))
        }
    }

    private func restartTutorial() {
        tutorialCompleted = false
        env.tutorialCoordinator.restart()
        path.removeAll()
    }
}
