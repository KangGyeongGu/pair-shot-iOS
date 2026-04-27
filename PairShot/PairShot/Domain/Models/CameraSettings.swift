import Foundation

nonisolated enum LensPosition: String, Codable, CaseIterable {
    case front
    case backWide
    case backUltraWide
    case backTele
    case backTriple
    case backDualWide
}

nonisolated enum FlashMode: String, Codable, CaseIterable {
    case off
    case on
    case auto
    case torch
}

nonisolated struct CameraSettings: Codable, Equatable {
    var zoomFactor: Double
    var lensPosition: LensPosition
    var flashMode: FlashMode
    var useGrid: Bool
    var useNightMode: Bool

    init(
        zoomFactor: Double = 1.0,
        lensPosition: LensPosition = .backWide,
        flashMode: FlashMode = .off,
        useGrid: Bool = false,
        useNightMode: Bool = false
    ) {
        self.zoomFactor = zoomFactor
        self.lensPosition = lensPosition
        self.flashMode = flashMode
        self.useGrid = useGrid
        self.useNightMode = useNightMode
    }
}
