import SwiftUI

struct HomeTutorialResumeAfterCamera: ViewModifier {
    let viewModel: HomeViewModel?
    let domainPairs: [PhotoPair]
    @Environment(AppEnvironment.self) private var env

    func body(content: Content) -> some View {
        content
            .task(id: viewModel == nil) { autoEnterAfterCameraIfNeeded() }
            .onChange(of: env.tutorialCoordinator.current) { _, _ in
                autoEnterAfterCameraIfNeeded()
            }
            .onChange(of: domainPairs.map(\.id)) { _, _ in
                autoEnterAfterCameraIfNeeded()
            }
    }

    private func autoEnterAfterCameraIfNeeded() {
        guard let viewModel else { return }
        guard !viewModel.didAutoResumeAfterCamera else { return }
        guard !viewModel.showAfterCamera else { return }
        guard let step = env.tutorialCoordinator.current else { return }
        guard TutorialStepRequirements.screen(for: step) == .afterCamera else { return }
        guard let tutorialPair = domainPairs.first(where: \.isTutorial) else { return }
        viewModel.didAutoResumeAfterCamera = true
        viewModel.afterCameraTargetPairId = tutorialPair.id
        viewModel.showAfterCamera = true
    }
}

struct FirstPairCardAnchor: ViewModifier {
    let isFirst: Bool

    func body(content: Content) -> some View {
        if isFirst {
            content.tutorialAnchor(TutorialAnchorID.homeFirstPairCard)
        } else {
            content
        }
    }
}

struct HomeSelectionPruner: ViewModifier {
    let viewModel: HomeViewModel
    let pairIds: [UUID]
    let albumIds: [UUID]

    func body(content: Content) -> some View {
        content
            .onChange(of: pairIds) { _, newIds in
                viewModel.pruneStalePairSelections(currentIds: Set(newIds))
            }
            .onChange(of: albumIds) { _, newIds in
                viewModel.pruneStaleAlbumSelections(currentIds: Set(newIds))
            }
    }
}

enum HomeDateFormatter {
    static func base(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return formatter.string(from: date)
    }
}
