import Foundation

nonisolated enum TutorialStep: Int, CaseIterable {
    case captureGuidePortrait = 0
    case captureGuideLeft
    case captureGuideRight
    case backToHome
    case tapPairCard
    case afterCameraStrip
    case afterCameraStripLongPressHint
    case afterCameraGuide
    case afterCameraInProgress
    case backToHome2
    case enterSelectionMode
    case selectionShare
    case selectionSave
    case selectionDelete
    case selectionExport
    case goSettings
    case done
}
