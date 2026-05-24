import SwiftUI

struct TutorialModeBinding: ViewModifier {
    let coordinator: TutorialCoordinator

    func body(content: Content) -> some View {
        content.environment(\.tutorialMode, coordinator.mode)
    }
}

extension View {
    func tutorialModeBinding(_ coordinator: TutorialCoordinator) -> some View {
        modifier(TutorialModeBinding(coordinator: coordinator))
    }
}
