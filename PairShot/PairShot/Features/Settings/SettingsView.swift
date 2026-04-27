import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppEnvironment.self) private var env
    @Environment(AdFreeStore.self) private var adFreeStore
    @State private var viewModel: SettingsViewModel?
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    form(for: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_button_done")) { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
        }
        .task { ensureViewModel() }
        .task { await observeEvents() }
        .task { await initialStorageRefresh() }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = env.makeSettingsViewModel()
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

    @ViewBuilder
    // swiftlint:disable switch_case_alignment
    private func destination(for route: Route) -> some View {
        switch route {
            case .watermarkSettings:
                WatermarkSettingsView(viewModel: env.makeWatermarkSettingsViewModel())

            case .combineSettings:
                CompositionSettingsGate {
                    CombineSettingsView(viewModel: env.makeCombineSettingsViewModel())
                }

            case .license:
                LicenseView()

            default:
                EmptyView()
        }
    }

    // swiftlint:enable switch_case_alignment

    private func form(for viewModel: SettingsViewModel) -> some View {
        SettingsFormBody(
            viewModel: viewModel,
            adFreeStore: adFreeStore,
            openURL: openURL
        )
    }
}

private struct SettingsFormBody: View {
    @Bindable var viewModel: SettingsViewModel
    let adFreeStore: AdFreeStore
    let openURL: OpenURLAction

    var body: some View {
        Form {
            SettingsGeneralSection(viewModel: viewModel)
            SettingsCaptureFileSection(viewModel: viewModel)
            SettingsWatermarkSection(viewModel: viewModel)
            SettingsCombineSection(viewModel: viewModel)
            SettingsCouponSection(adFreeStore: adFreeStore)
            SettingsStorageInfoSection(viewModel: viewModel, openURL: openURL)
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.refreshStorageInfo() }
        .confirmationDialog(
            String(localized: "settings_dialog_language_title"),
            isPresented: $viewModel.showLanguagePicker,
            titleVisibility: .visible
        ) {
            Button(String(localized: "language_system")) { viewModel.setLanguage(.system) }
            Button(String(localized: "language_korean")) { viewModel.setLanguage(.korean) }
            Button(String(localized: "English")) { viewModel.setLanguage(.english) }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            String(localized: "settings_dialog_theme_title"),
            isPresented: $viewModel.showThemePicker,
            titleVisibility: .visible
        ) {
            Button(String(localized: "theme_system")) { viewModel.setTheme(.system) }
            Button(String(localized: "theme_light")) { viewModel.setTheme(.light) }
            Button(String(localized: "theme_dark")) { viewModel.setTheme(.dark) }
            Button(String(localized: "common_button_cancel"), role: .cancel) {}
        }
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
    }
}
