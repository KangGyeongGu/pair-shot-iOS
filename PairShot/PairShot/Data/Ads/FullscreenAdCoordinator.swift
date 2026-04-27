import Foundation
import OSLog
import SwiftUI

actor FullscreenAdCoordinator {
    private(set) var isShowing: Bool = false

    init() {}

    func tryAcquire() -> Bool {
        guard !isShowing else {
            AppLogger.ads.debug("FullscreenAdCoordinator acquire denied (already showing)")
            return false
        }
        isShowing = true
        return true
    }

    func release() {
        isShowing = false
    }
}

extension EnvironmentValues {
    @Entry var fullscreenAdCoordinator: FullscreenAdCoordinator = .init()
}
