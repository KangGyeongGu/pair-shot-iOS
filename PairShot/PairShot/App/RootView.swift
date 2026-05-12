import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showFallbackAlert: Bool

    @State private var path: [Route] = []

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
                .toolbarColorScheme(colorScheme, for: .navigationBar)
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

    init(showFallbackAlert: Binding<Bool> = .constant(false)) {
        _showFallbackAlert = showFallbackAlert
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
            case .home: homeDestination()
            case let .albumDetail(albumId): albumDetailDestination(albumId: albumId)
            case .settings: SettingsView(path: $path)
            case .watermarkSettings: WatermarkSettingsView(viewModel: env.makeWatermarkSettingsViewModel())
            case .combineSettings: CombineSettingsView(viewModel: env.makeCombineSettingsViewModel())
            case .license: LicenseView()
            case .languagePicker: LanguagePickerView(viewModel: env.makeSettingsViewModel())
            case .themePicker: ThemePickerView(viewModel: env.makeSettingsViewModel())
            case .imageQualityPicker: ImageQualityPickerView(viewModel: env.makeSettingsViewModel())
            case .filenamePrefixEditor: FilenamePrefixView(viewModel: env.makeSettingsViewModel())
            case let .exportSettings(pairIds): exportSettingsDestination(pairIds: pairIds)
            case .pairPreview: EmptyView()
        }
    }

    private func homeDestination() -> some View {
        HomeView(
            onOpenAlbum: { albumId in
                path.append(.albumDetail(albumId: albumId))
            },
            onPushExportSettings: { pairIds in
                path.append(.exportSettings(pairIds: pairIds))
            },
            onPushSettings: {
                path.append(.settings)
            }
        )
    }

    private func albumDetailDestination(albumId: UUID) -> some View {
        AlbumDetailView(
            albumId: albumId,
            onPushExportSettings: { pairIds in
                path.append(.exportSettings(pairIds: pairIds))
            }
        )
    }

    private func exportSettingsDestination(pairIds: [UUID]) -> some View {
        ExportSettingsView(
            viewModel: env.makeExportSettingsViewModel(pairIds: pairIds),
            onPushWatermarkSettings: {
                path.append(.watermarkSettings)
            },
            onPushCombineSettings: {
                path.append(.combineSettings)
            }
        )
    }
}

#Preview {
    PreviewEnvironment(suiteName: "preview-root") {
        RootView()
    }
}
