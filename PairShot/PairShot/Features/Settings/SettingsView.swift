import SwiftUI

struct SettingsView: View {
    @Binding var path: [Route]
    @Environment(\.openURL) private var openURL
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        VStack(spacing: 0) {
            BannerAdSlot()

            Group {
                if let viewModel {
                    form(for: viewModel)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(String(localized: "settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { ensureViewModel() }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeSettingsViewModel()
        }
        consumePendingPulseIfNeeded()
    }

    private func consumePendingPulseIfNeeded() {
        guard let viewModel,
              let target = env.settingsRedirectCoordinator.consume()
        else { return }
        switch target {
            case .watermark: viewModel.triggerPulse(\.shouldPulseWatermark)
            case .combine: viewModel.triggerPulse(\.shouldPulseCombine)
        }
    }

    private func form(for viewModel: SettingsViewModel) -> some View {
        SettingsFormBody(
            viewModel: viewModel,
            openURL: openURL,
            path: $path,
        )
    }
}

private struct SettingsFormBody: View {
    @Bindable var viewModel: SettingsViewModel
    let openURL: OpenURLAction
    @Binding var path: [Route]
    @State private var showPaywall: Bool = false
    @Environment(RewardedAdManager.self) private var rewardedManager
    @Environment(\.fullscreenAdCoordinator) private var coordinator

    var body: some View {
        Form {
            if !(viewModel.membership?.proIsActive ?? false) {
                Section {
                    SettingsProPromoCard(onLearnMore: { showPaywall = true })
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            SubscriptionSettingsSection(showPaywall: $showPaywall)
            SettingsCaptureFileSection(viewModel: viewModel, path: $path)
            SettingsWatermarkSection(viewModel: viewModel, path: $path)
            SettingsCombineSection(viewModel: viewModel, path: $path)
            SettingsGeneralSection(viewModel: viewModel, path: $path)
            SettingsHelpSection(path: $path)
            SettingsStorageInfoSection(viewModel: viewModel, openURL: openURL, path: $path)
        }
        .listStyle(.insetGrouped)
        .paywallSheet(isPresented: $showPaywall)
        .alert(
            String(localized: "settings_language_restart_title"),
            isPresented: $viewModel.showLanguageRestartAlert,
        ) {
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                viewModel.showLanguageRestartAlert = false
            }
        } message: {
            Text(String(localized: "settings_language_restart_message"))
        }
        .alert(
            String(localized: "rewarded_gate_title"),
            isPresented: $viewModel.showWatermarkGateDialog,
        ) {
            Button(String(localized: "rewarded_gate_confirm")) {
                Task { await confirmWatermarkGate() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "rewarded_gate_body_watermark_detail"))
        }
        .alert(
            String(localized: "rewarded_gate_title"),
            isPresented: $viewModel.showCombineGateDialog,
        ) {
            Button(String(localized: "rewarded_gate_confirm")) {
                Task { await confirmCombineGate() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "rewarded_gate_body_combine_detail"))
        }
    }

    @MainActor
    private func confirmWatermarkGate() async {
        let result = await viewModel.confirmWatermarkGateAd(
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController(),
        )
        if case .proceed = result {
            path.append(.watermarkSettings)
        }
    }

    @MainActor
    private func confirmCombineGate() async {
        let result = await viewModel.confirmCombineGateAd(
            rewardedManager: rewardedManager,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController(),
        )
        if case .proceed = result {
            path.append(.combineSettings)
        }
    }
}
