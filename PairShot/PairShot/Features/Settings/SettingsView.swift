import SwiftUI

struct SettingsView: View {
    @Binding var path: [Route]
    @Environment(\.dismiss) private var dismiss
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
        .task { await observeEvents() }
        .task { await initialStorageRefresh() }
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

    private func observeEvents() async {
        guard let viewModel else { return }
        for await event in viewModel.events {
            switch event {
                case .dismiss:
                    dismiss()
            }
        }
    }

    private func initialStorageRefresh() async {
        guard let viewModel else { return }
        await viewModel.refreshStorageInfo()
    }

    private func form(for viewModel: SettingsViewModel) -> some View {
        SettingsFormBody(
            viewModel: viewModel,
            openURL: openURL,
            path: $path
        )
    }
}

private struct SettingsFormBody: View {
    @Bindable var viewModel: SettingsViewModel
    let openURL: OpenURLAction
    @Binding var path: [Route]

    var body: some View {
        Form {
            SettingsGeneralSection(viewModel: viewModel, path: $path)
            SettingsCaptureFileSection(viewModel: viewModel, path: $path)
            SettingsWatermarkSection(viewModel: viewModel, path: $path)
            SettingsCombineSection(viewModel: viewModel, path: $path)
            SettingsPrivacySection(viewModel: viewModel)
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
}
