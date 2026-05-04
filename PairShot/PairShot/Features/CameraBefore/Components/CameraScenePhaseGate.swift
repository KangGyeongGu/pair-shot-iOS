import Foundation
import SwiftUI

enum CameraSessionAction: Equatable {
    case stop
    case start
}

enum CameraScenePhaseGate {
    static func action(for newPhase: ScenePhase) -> CameraSessionAction? {
        switch newPhase {
            case .background: .stop
            case .active: .start
            case .inactive: nil
            @unknown default: nil
        }
    }
}
