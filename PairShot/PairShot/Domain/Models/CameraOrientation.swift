nonisolated enum CameraOrientation: Int {
    case landscapeLeft = 0
    case portrait = 1
    case landscapeRight = 2
    case upsideDown = 3

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
}
