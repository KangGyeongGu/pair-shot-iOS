import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showFallbackAlert: Bool

    @State private var path: [Route] = []
    @State private var showFirstRunPaywall = false
    @AppStorage("tutorial.completed") private var tutorialCompleted = false

    var body: some View {
        ZStack {
            if env.permissionStatusService.isBlocked {
                PermissionGateView(
                    viewModel: PermissionGateViewModel(
                        permissionStatusService: env.permissionStatusService,
                    ),
                )
            } else {
                NavigationStack(path: $path) {
                    BeforeCameraView(albumId: nil, onHome: { path.append(.home) })
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
                .toolbarColorScheme(colorScheme, for: .navigationBar)
                .fullScreenCover(isPresented: $showFirstRunPaywall) {
                    PaywallView(mode: .firstRun) {
                        env.appSettings.hasCompletedFirstRunPaywall = true
                        showFirstRunPaywall = false
                    }
                }
                .task {
                    if tutorialCompleted {
                        evaluateFirstRunPaywall()
                    } else {
                        startTutorialIfFirstRun()
                    }
                }
                .onChange(of: env.membership.proIsActive) { _, _ in
                    evaluateFirstRunPaywall()
                }
                .onChange(of: env.tutorialCoordinator.current) { oldValue, newValue in
                    syncTutorialPersistedState(newValue)
                    if newValue == .done {
                        tutorialCompleted = true
                    }
                    if oldValue != nil, newValue == nil {
                        tutorialCompleted = true
                        evaluateFirstRunPaywall()
                    }
                }
            }
        }
        .alert(
            String(localized: "root_storage_init_failed_title"),
            isPresented: $showFallbackAlert,
        ) {
            Button(String(localized: "common_button_confirm"), role: .cancel) {
                showFallbackAlert = false
            }
        } message: {
            Text(String(localized: "root_storage_init_failed_message"))
        }
        .snackbarOverlay(env.snackbarQueue)
        .tutorialOverlay()
    }

    init(showFallbackAlert: Binding<Bool> = .constant(false)) {
        _showFallbackAlert = showFallbackAlert
    }

    private func startTutorialIfFirstRun() {
        guard !tutorialCompleted else { return }
        guard !env.tutorialCoordinator.isActive else { return }
        guard env.tutorialCoordinator.current == nil else { return }
        if let raw = env.appSettings.tutorialCurrentStepRawValue,
           let step = TutorialStep(rawValue: raw),
           step != .done
        {
            let resumeStep = TutorialStepRequirements.normalizeForResume(step)
            env.tutorialCoordinator.resume(at: resumeStep)
            restorePathForResumedStep(resumeStep)
        } else {
            env.tutorialCoordinator.start()
        }
    }

    private func restorePathForResumedStep(_ step: TutorialStep) {
        let screen = TutorialStepRequirements.screen(for: step)
        switch screen {
            case .home, .afterCamera, .settings, .exportSettings:
                if path != [.home] {
                    path = [.home]
                }

            case .beforeCamera, .any:
                break
        }
    }

    private func syncTutorialPersistedState(_ step: TutorialStep?) {
        guard let step, step != .done else {
            env.appSettings.tutorialCurrentStepRawValue = nil
            return
        }
        env.appSettings.tutorialCurrentStepRawValue = step.rawValue
    }

    private func evaluateFirstRunPaywall() {
        guard !env.appSettings.hasCompletedFirstRunPaywall else { return }
        guard !env.membership.proIsActive else {
            env.appSettings.hasCompletedFirstRunPaywall = true
            return
        }
        showFirstRunPaywall = true
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
            case .home: homeDestination()
            case let .albumDetail(albumId): albumDetailDestination(albumId: albumId)
            case .settings: SettingsView(path: $path)
            case .watermarkSettings: WatermarkSettingsView(viewModel: env.makeWatermarkSettingsViewModel())
            case .combineSettings: CombineSettingsView(viewModel: env.makeCombineSettingsViewModel())
            case .info: InfoView()
            case .license: LicenseView()
            case .businessInfo: BusinessInfoView()
            case .languagePicker: LanguagePickerView(viewModel: env.makeSettingsViewModel())
            case .themePicker: ThemePickerView(viewModel: env.makeSettingsViewModel())
            case .imageQualityPicker: ImageQualityPickerView(viewModel: env.makeSettingsViewModel())
            case .filenamePrefixEditor: FilenamePrefixView(viewModel: env.makeSettingsViewModel())
            case .textSizePicker: TextSizePickerView(viewModel: env.makeSettingsViewModel())
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
            },
        )
    }

    private func albumDetailDestination(albumId: UUID) -> some View {
        AlbumDetailView(
            albumId: albumId,
            onPushExportSettings: { pairIds in
                path.append(.exportSettings(pairIds: pairIds))
            },
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
            },
        )
    }
}

#Preview {
    PreviewEnvironment(suiteName: "preview-root") {
        RootView()
    }
}
