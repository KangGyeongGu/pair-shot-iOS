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
            .navigationTitle(String(localized: "설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "완료")) { dismiss() }
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
            String(localized: "언어 선택"),
            isPresented: $viewModel.showLanguagePicker,
            titleVisibility: .visible
        ) {
            Button(String(localized: "시스템 기본값")) { viewModel.setLanguage(.system) }
            Button(String(localized: "한국어")) { viewModel.setLanguage(.korean) }
            Button(String(localized: "English")) { viewModel.setLanguage(.english) }
            Button(String(localized: "취소"), role: .cancel) {}
        }
        .confirmationDialog(
            String(localized: "테마 선택"),
            isPresented: $viewModel.showThemePicker,
            titleVisibility: .visible
        ) {
            Button(String(localized: "시스템 기본값")) { viewModel.setTheme(.system) }
            Button(String(localized: "라이트")) { viewModel.setTheme(.light) }
            Button(String(localized: "다크")) { viewModel.setTheme(.dark) }
            Button(String(localized: "취소"), role: .cancel) {}
        }
        .alert(
            String(localized: "캐시 초기화"),
            isPresented: $viewModel.showCacheClearConfirm
        ) {
            Button(String(localized: "초기화"), role: .destructive) {
                Task { await viewModel.clearCache() }
            }
            Button(String(localized: "취소"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "캐시를 초기화하시겠습니까?\n썸네일이 삭제되며, 다시 생성됩니다."
            ))
        }
    }
}
