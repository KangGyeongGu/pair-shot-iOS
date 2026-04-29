import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

nonisolated enum ExifOrientationCodec {
    static func write(
        _ orientation: CGImagePropertyOrientation,
        to jpeg: Data
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else { return nil }
        guard CGImageSourceGetType(source) != nil else { return nil }
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let metadata: [String: Any] = [
            kCGImagePropertyOrientation as String: orientation.rawValue,
        ]
        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    static func read(from jpeg: Data) -> CGImagePropertyOrientation? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        if let raw = props[kCGImagePropertyOrientation as String] as? UInt32 {
            return CGImagePropertyOrientation(rawValue: raw)
        }
        if let raw = props[kCGImagePropertyOrientation as String] as? Int {
            return CGImagePropertyOrientation(rawValue: UInt32(raw))
        }
        return nil
    }

    static func fromCaptureAngle(_ angle: CGFloat) -> CGImagePropertyOrientation {
        let degrees = ((angle.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let normalized = Int(degrees.rounded())
        switch normalized {
            case 0: return .up
            case 90: return .right
            case 180: return .down
            case 270: return .left
            default: return .up
        }
    }
}
