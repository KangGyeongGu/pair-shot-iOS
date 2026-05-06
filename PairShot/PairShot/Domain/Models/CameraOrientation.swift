import Foundation

nonisolated enum CameraOrientation: Int {
    case landscapeLeft = 0
    case portrait = 1
    case landscapeRight = 2
    case upsideDown = 3

    init(captureAngleDegrees angle: Double) {
        let normalized = ((angle.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let bucket = Int(((normalized + 45) / 90).rounded(.down)) % 4
        self = CameraOrientation(rawValue: bucket) ?? .portrait
    }

    init?(gravityX x: Double, gravityY y: Double, threshold: Double = 0.6) {
        if y < -threshold {
            self = .portrait
            return
        }
        if y > threshold {
            self = .upsideDown
            return
        }
        if x < -threshold {
            self = .landscapeLeft
            return
        }
        if x > threshold {
            self = .landscapeRight
            return
        }
        return nil
    }

    var ghostRotationDegrees: Double {
        switch self {
            case .landscapeLeft: 90
            case .portrait: 0
            case .landscapeRight: -90
            case .upsideDown: 180
        }
    }
}
