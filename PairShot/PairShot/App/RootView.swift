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
            String(localized: "저장소 초기화 실패"),
            isPresented: $showFallbackAlert
        ) {
            Button(String(localized: "확인"), role: .cancel) {
                showFallbackAlert = false
            }
        } message: {
            Text(String(
                localized: "일시 모드로 동작합니다. 데이터가 보존되지 않습니다. 앱 재시작 후에도 문제가 지속되면 재설치가 필요합니다."
            ))
        }
    }

    @ViewBuilder
    // swiftlint:disable switch_case_alignment
    private func destination(for route: Route) -> some View {
        switch route {
            case .home:
                HomeView(onOpenAlbum: { albumId in
                    path.append(.albumDetail(albumId: albumId))
                })

            case let .albumDetail(albumId):
                AlbumDetailView(albumId: albumId)

            case let .pairPicker(albumId):
                PairPickerView(albumId: albumId)

            case .watermarkSettings:
                WatermarkSettingsView(viewModel: env.makeWatermarkSettingsViewModel())

            case .combineSettings:
                CombineSettingsView(viewModel: env.makeCombineSettingsViewModel())

            case .license:
                LicenseView()

            case .pairPreview,
                 .settings,
                 .exportSettings:
                EmptyView()
        }
    }
    // swiftlint:enable switch_case_alignment
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
