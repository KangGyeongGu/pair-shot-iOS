import Foundation

nonisolated enum TutorialStep: Int, CaseIterable {
    case homeCaptureHighlight = 0
    case captureGuidePortrait
    case captureGuideLeft
    case captureGuideRight
    case backToHome
    case tapPairCard
    case afterCameraGuide
    case backToHome2
    case enterSelectionMode
    case selectionShare
    case selectionSave
    case selectionDelete
    case selectionExport
    case saveToDevice
    case goSettings
    case done
}
