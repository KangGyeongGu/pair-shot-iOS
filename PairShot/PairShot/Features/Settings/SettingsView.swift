import SwiftUI

struct SettingsView: View {
    @Binding var path: [Route]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppEnvironment.self) private var env
    @Environment(AdFreeStore.self) private var adFreeStore
    @Environment(RewardedAdManager.self) private var rewardedManager
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
        .task { await observeEvents() }
        .task { await initialStorageRefresh() }
        .task { rewardedManager.loadIfNeeded(adFreeStore: adFreeStore) }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeSettingsViewModel()
        }
        consumePendingPulseIfNeeded()
    }

    // swiftlint:disable switch_case_alignment switch_case_on_newline
    private func consumePendingPulseIfNeeded() {
        guard let viewModel,
              let target = env.settingsRedirectCoordinator.consume()
        else { return }
        switch target {
            case .watermark: viewModel.triggerPulse(\.shouldPulseWatermark)
            case .combine: viewModel.triggerPulse(\.shouldPulseCombine)
        }
    }

    // swiftlint:enable switch_case_alignment switch_case_on_newline

    private func observeEvents() async {
        guard let viewModel else { return }
        for await event in viewModel.events {
            // swiftlint:disable switch_case_alignment
            switch event {
                case .dismiss:
                    dismiss()
            }
            // swiftlint:enable switch_case_alignment
        }
    }

    private func initialStorageRefresh() async {
        guard let viewModel else { return }
        await viewModel.refreshStorageInfo()
    }

    private func form(for viewModel: SettingsViewModel) -> some View {
        SettingsFormBody(
            viewModel: viewModel,
            adFreeStore: adFreeStore,
            openURL: openURL,
            path: $path
        )
    }
}

private struct SettingsFormBody: View {
    @Bindable var viewModel: SettingsViewModel
    let adFreeStore: AdFreeStore
    let openURL: OpenURLAction
    @Binding var path: [Route]

    @Environment(RewardedAdManager.self) private var rewardedManager
    @Environment(\.fullscreenAdCoordinator) private var coordinator

    var body: some View {
        Form {
            SettingsGeneralSection(viewModel: viewModel, path: $path)
            SettingsCaptureFileSection(viewModel: viewModel, path: $path)
            SettingsWatermarkSection(viewModel: viewModel, path: $path)
            SettingsCombineSection(viewModel: viewModel, path: $path)
            SettingsCouponSection(adFreeStore: adFreeStore)
            SettingsStorageInfoSection(viewModel: viewModel, openURL: openURL)
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.refreshStorageInfo() }
        .alert(
            String(localized: "settings_dialog_cache_clear_title"),
            isPresented: $viewModel.showCacheClearConfirm
        ) {
            Button(String(localized: "settings_dialog_cache_clear_button"), role: .destructive) {
                Task { await viewModel.clearCache() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings_dialog_cache_clear_message"))
        }
        .alert(
            String(localized: "rewarded_gate_title"),
            isPresented: $viewModel.showWatermarkGateDialog
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
            isPresented: $viewModel.showCombineGateDialog
        ) {
            Button(String(localized: "rewarded_gate_confirm")) {
                Task { await confirmCombineGate() }
            }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "rewarded_gate_body_combine_detail"))
        }
        .alert(
            String(localized: "settings_language_restart_title"),
            isPresented: $viewModel.showLanguageRestartAlert
        ) {
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                viewModel.showLanguageRestartAlert = false
            }
        } message: {
            Text(String(localized: "settings_language_restart_message"))
        }
    }

    @MainActor
    private func confirmWatermarkGate() async {
        let result = await viewModel.confirmWatermarkGateAd(
            rewardedManager: rewardedManager,
            adFreeStore: adFreeStore,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController()
        )
        if case .proceed = result {
            path.append(.watermarkSettings)
        }
    }

    @MainActor
    private func confirmCombineGate() async {
        let result = await viewModel.confirmCombineGateAd(
            rewardedManager: rewardedManager,
            adFreeStore: adFreeStore,
            coordinator: coordinator,
            rootViewController: BannerAdView.resolveTopPresentedViewController()
        )
        if case .proceed = result {
            path.append(.combineSettings)
        }
    }
}
