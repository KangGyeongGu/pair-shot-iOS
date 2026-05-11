@preconcurrency import AVFoundation
import Foundation

nonisolated enum LensPosition: String, Codable, CaseIterable {
    case front
    case backWide
    case backUltraWide
    case backTele
    case backTriple
    case backDualWide

    static func resolve(identifier: String?) -> Self {
        guard let identifier else { return .backWide }
        let parts = identifier.split(separator: ".", maxSplits: 1).map(String.init)
        guard let typeRaw = parts.first else { return .backWide }
        let position = parts.count > 1 ? parts[1] : "back"
        if position == "front" { return .front }
        switch typeRaw {
            case AVCaptureDevice.DeviceType.builtInUltraWideCamera.rawValue:
                return .backUltraWide

            case AVCaptureDevice.DeviceType.builtInTelephotoCamera.rawValue:
                return .backTele

            case AVCaptureDevice.DeviceType.builtInTripleCamera.rawValue:
                return .backTriple

            case AVCaptureDevice.DeviceType.builtInDualWideCamera.rawValue,
                 AVCaptureDevice.DeviceType.builtInDualCamera.rawValue:
                return .backDualWide

            default:
                return .backWide
        }
    }
}

nonisolated struct CameraSettings: Codable, Equatable {
    var zoomFactor: Double
    var lensPosition: LensPosition

    init(
        zoomFactor: Double = 1.0,
        lensPosition: LensPosition = .backWide
    ) {
        self.zoomFactor = zoomFactor
        self.lensPosition = lensPosition
    }
}
