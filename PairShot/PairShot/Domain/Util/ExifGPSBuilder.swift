import Foundation
import ImageIO

nonisolated enum ExifGPSBuilder {
    static func metadata(
        from location: DomainLocation?,
        timestamp: Date = .now,
    ) -> [String: Any] {
        guard let location else { return [:] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let gps: [String: Any] = [
            kCGImagePropertyGPSLatitude as String: abs(location.latitude),
            kCGImagePropertyGPSLatitudeRef as String: location.latitude >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude as String: abs(location.longitude),
            kCGImagePropertyGPSLongitudeRef as String: location.longitude >= 0 ? "E" : "W",
            kCGImagePropertyGPSTimeStamp as String: formatter.string(from: timestamp),
        ]
        return [kCGImagePropertyGPSDictionary as String: gps]
    }
}
