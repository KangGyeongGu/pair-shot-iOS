import Foundation
import SwiftData
import SwiftUI
import UIKit

enum CaptureActionError: Error {
    case session(CameraSessionError)
    case storage(Error)
    case persistence(Error)
}

@MainActor
enum CaptureHaptics {
    static func success(_ haptics: HapticService) {
        haptics.notify(.success)
    }
}
