import Foundation

nonisolated enum TutorialPosture: Equatable {
    case portrait
    case leftLandscape
    case rightLandscape
    case unknown
}

nonisolated enum TutorialMotionGuide {
    static let portraitTolerance: Double = 20
    static let landscapeCenterMagnitude: Double = 90
    static let landscapeTolerance: Double = 20

    static func posture(forRollDegrees rollDegrees: Double) -> TutorialPosture {
        guard rollDegrees.isFinite else { return .unknown }
        if abs(rollDegrees) < portraitTolerance {
            return .portrait
        }
        if isWithin(rollDegrees, center: -landscapeCenterMagnitude, tolerance: landscapeTolerance) {
            return .leftLandscape
        }
        if isWithin(rollDegrees, center: landscapeCenterMagnitude, tolerance: landscapeTolerance) {
            return .rightLandscape
        }
        return .unknown
    }

    static func matches(step: TutorialStep, posture: TutorialPosture) -> Bool {
        switch step {
            case .captureGuidePortrait: posture == .portrait
            case .captureGuideLeft: posture == .leftLandscape
            case .captureGuideRight: posture == .rightLandscape
            default: false
        }
    }

    static func postureRequiringStep(_ step: TutorialStep) -> Bool {
        switch step {
            case .captureGuidePortrait, .captureGuideLeft, .captureGuideRight: true
            default: false
        }
    }

    private static func isWithin(_ value: Double, center: Double, tolerance: Double) -> Bool {
        let lower = center - tolerance
        let upper = center + tolerance
        return value > lower && value < upper
    }
}
