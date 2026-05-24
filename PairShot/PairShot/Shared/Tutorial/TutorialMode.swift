import SwiftUI

nonisolated enum TutorialMode: Equatable {
    case off
    case running(TutorialStep)
}

extension EnvironmentValues {
    @Entry var tutorialMode: TutorialMode = .off
}
