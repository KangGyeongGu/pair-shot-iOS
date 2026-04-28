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
        ZStack {
            if env.permissionStatusService.isBlocked {
                PermissionGateView(
                    viewModel: PermissionGateViewModel(
                        permissionStatusService: env.permissionStatusService
                    )
                )
            } else {
                NavigationStack(path: $path) {
                    BeforeCameraView(albumId: nil, onHome: { path.append(.home) })
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
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
    // swiftlint:disable switch_case_alignment cyclomatic_complexity
    private func destination(for route: Route) -> some View {
        switch route {
            case .home:
                HomeView(
                    onOpenAlbum: { albumId in
                        path.append(.albumDetail(albumId: albumId))
                    },
                    onPushExportSettings: { pairIds in
                        path.append(.exportSettings(pairIds: pairIds, albumId: nil))
                    },
                    onPushSettings: {
                        path.append(.settings)
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

            case .settings:
                SettingsView(path: $path)

            case .watermarkSettings:
                WatermarkSettingsView(viewModel: env.makeWatermarkSettingsViewModel())

            case .combineSettings:
                CombineSettingsView(viewModel: env.makeCombineSettingsViewModel())

            case .license:
                LicenseView()

            case .languagePicker:
                LanguagePickerView(viewModel: env.makeSettingsViewModel())

            case .themePicker:
                ThemePickerView(viewModel: env.makeSettingsViewModel())

            case .imageQualityPicker:
                ImageQualityPickerView(viewModel: env.makeSettingsViewModel())

            case .filenamePrefixEditor:
                FilenamePrefixView(viewModel: env.makeSettingsViewModel())

            case let .exportSettings(pairIds, albumId):
                ExportSettingsView(
                    viewModel: env.makeExportSettingsViewModel(
                        pairIds: pairIds,
                        albumId: albumId
                    ),
                    onPushWatermarkSettings: {
                        path.append(.watermarkSettings)
                    },
                    onPushCombineSettings: {
                        path.append(.combineSettings)
                    }
                )

            case .pairPreview:
                EmptyView()
        }
    }

    // swiftlint:enable switch_case_alignment cyclomatic_complexity
}

private struct RootViewPreviewWrapper: View {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Schema([Album.self, PhotoPair.self, Coupon.self]),
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
