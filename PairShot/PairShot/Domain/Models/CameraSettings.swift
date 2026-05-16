@preconcurrency import AVFoundation
import CoreGraphics
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

nonisolated enum AspectRatio: String, Codable, CaseIterable, Equatable {
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case square = "1:1"

    static let `default`: Self = .fourThree

    var next: Self {
        switch self {
            case .fourThree: .sixteenNine
            case .sixteenNine: .square
            case .square: .fourThree
        }
    }

    var portraitHeightMultiplier: CGFloat {
        switch self {
            case .fourThree: 4.0 / 3.0
            case .sixteenNine: 16.0 / 9.0
            case .square: 1.0
        }
    }

    var label: String {
        rawValue
    }
}

nonisolated struct CameraSettings: Codable, Equatable {
    var zoomFactor: Double
    var lensPosition: LensPosition
    var aspectRatio: AspectRatio?

    var resolvedAspectRatio: AspectRatio {
        aspectRatio ?? .default
    }

    init(
        zoomFactor: Double = 1.0,
        lensPosition: LensPosition = .backWide,
        aspectRatio: AspectRatio? = nil,
    ) {
        self.zoomFactor = zoomFactor
        self.lensPosition = lensPosition
        self.aspectRatio = aspectRatio
    }
}
