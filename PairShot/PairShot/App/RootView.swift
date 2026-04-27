import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Binding var showFallbackAlert: Bool

    @State private var path: [Route] = []

    // swiftlint:disable:next type_contents_order
    init(showFallbackAlert: Binding<Bool> = .constant(false)) {
        _showFallbackAlert = showFallbackAlert
    }

    var body: some View {
        NavigationStack(path: $path) {
            BeforeCameraView(albumId: nil, onHome: { path.append(.home) })
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .alert(
            String(localized: "root_storage_init_failed_title"),
            isPresented: $showFallbackAlert
        ) {
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                showFallbackAlert = false
            }
        } message: {
            Text(String(localized: "root_storage_init_failed_message"))
        }
        .snackbarOverlay(env.snackbarQueue)
    }

    @ViewBuilder
    // swiftlint:disable switch_case_alignment
    private func destination(for route: Route) -> some View {
        switch route {
            case .home:
                HomeView(
                    onOpenAlbum: { albumId in
                        path.append(.albumDetail(albumId: albumId))
                    },
                    onPushExportSettings: { pairIds in
                        path.append(.exportSettings(pairIds: pairIds, albumId: nil))
                    }
                )

            case let .albumDetail(albumId):
                AlbumDetailView(
                    albumId: albumId,
                    onPushExportSettings: { pairIds in
                        path.append(.exportSettings(pairIds: pairIds, albumId: albumId))
                    }
                )

            case let .pairPicker(albumId):
                PairPickerView(albumId: albumId)

            case .watermarkSettings:
                WatermarkSettingsView(viewModel: env.makeWatermarkSettingsViewModel())

            case .combineSettings:
                CombineSettingsView(viewModel: env.makeCombineSettingsViewModel())

            case .license:
                LicenseView()

            case let .exportSettings(pairIds, albumId):
                ExportSettingsView(
                    viewModel: env.makeExportSettingsViewModel(
                        pairIds: pairIds,
                        albumId: albumId
                    ),
                    onRequestSettingsRedirect: { target in
                        handleExportSettingsRedirect(target)
                    }
                )

            case .pairPreview,
                 .settings,
                 .languagePicker,
                 .themePicker,
                 .imageQualityPicker,
                 .filenamePrefixEditor:
                EmptyView()
        }
    }

    // swiftlint:enable switch_case_alignment

    private func handleExportSettingsRedirect(_ target: ExportSettingsRedirectTarget) {
        env.settingsRedirectCoordinator.request(pulseTarget(for: target))
        path = [.home]
    }

    // swiftlint:disable switch_case_alignment switch_case_on_newline
    private func pulseTarget(for target: ExportSettingsRedirectTarget) -> SettingsPulseTarget {
        switch target {
            case .watermarkSettings: .watermark
            case .combineSettings: .combine
        }
    }
    // swiftlint:enable switch_case_alignment switch_case_on_newline
}

private struct RootViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Schema(versionedSchema: SchemaV2.self),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    var body: some View {
        let appSettings = AppSettings(defaults: UserDefaults(suiteName: "preview-root") ?? .standard)
        let env = AppEnvironment(modelContainer: container, appSettings: appSettings)
        return RootView()
            .modelContainer(container)
            .environment(env)
            .environment(env.adFreeStore)
            .environment(\.fullscreenAdCoordinator, env.fullscreenAdCoordinator)
            .environment(env.interstitialAdManager)
            .environment(env.appOpenAdManager)
            .environment(env.rewardedAdManager)
            .environment(env.nativeAdLoader)
            .environment(env.trackingService)
            .environment(env.appSettings)
    }
}

#Preview {
    RootViewPreviewWrapper()
}
