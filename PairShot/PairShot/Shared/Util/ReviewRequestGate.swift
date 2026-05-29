import Foundation

nonisolated enum ReviewRequestGate {
    static let triggerLaunchCount = 3

    static func shouldRequest(
        launchCount: Int,
        didRequest: Bool,
        tutorialActive: Bool,
    ) -> Bool {
        guard !didRequest else { return false }
        guard !tutorialActive else { return false }
        return launchCount >= triggerLaunchCount
    }
}
