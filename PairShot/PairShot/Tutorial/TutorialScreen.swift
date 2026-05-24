nonisolated enum TutorialScreen: Equatable {
    case beforeCamera
    case home
    case afterCamera
    case exportSettings
    case settings
    case any
}

nonisolated enum TutorialStepRequirements {
    static func screen(for step: TutorialStep) -> TutorialScreen {
        switch step {
            case .captureGuidePortrait,
                 .captureGuideLeft,
                 .captureGuideRight,
                 .backToHome:
                .beforeCamera

            case .tapPairCard,
                 .enterSelectionMode,
                 .selectionShare,
                 .selectionSave,
                 .selectionDelete,
                 .selectionExport,
                 .goSettings:
                .home

            case .afterCameraStrip,
                 .afterCameraStripLongPressHint,
                 .afterCameraStripPeekClose,
                 .afterCameraGuide,
                 .afterCameraInProgress,
                 .backToHome2:
                .afterCamera

            case .done:
                .any
        }
    }

    static func requiresSelectionMode(_ step: TutorialStep) -> Bool {
        switch step {
            case .selectionShare,
                 .selectionSave,
                 .selectionDelete,
                 .selectionExport:
                true

            default:
                false
        }
    }

    static func requiresFirstPairSelected(_ step: TutorialStep) -> Bool {
        switch step {
            case .afterCameraStrip,
                 .afterCameraStripLongPressHint:
                true

            default:
                false
        }
    }

    static func normalizeForResume(_ step: TutorialStep) -> TutorialStep {
        switch step {
            case .afterCameraStripPeekClose, .afterCameraInProgress:
                .afterCameraGuide

            default:
                step
        }
    }
}
