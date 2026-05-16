import Foundation
import ImageIO
@testable import PairShot
import Testing

struct ExifGPSBuilderTests {
    @Test
    func `nil location yields empty dictionary`() {
        let result = ExifGPSBuilder.metadata(from: nil)
        #expect(result.isEmpty)
    }

    @Test
    func `Positive latitude/longitude uses N/E refs with absolute values`() {
        let location = DomainLocation(latitude: 37.5665, longitude: 126.9780)
        let result = ExifGPSBuilder.metadata(from: location)
        let gps = result[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        #expect(gps?[kCGImagePropertyGPSLatitudeRef as String] as? String == "N")
        #expect(gps?[kCGImagePropertyGPSLongitudeRef as String] as? String == "E")
        #expect(gps?[kCGImagePropertyGPSLatitude as String] as? Double == 37.5665)
        #expect(gps?[kCGImagePropertyGPSLongitude as String] as? Double == 126.9780)
    }

    @Test
    func `Negative latitude/longitude uses S/W refs with absolute values`() {
        let location = DomainLocation(latitude: -33.8688, longitude: -70.6483)
        let result = ExifGPSBuilder.metadata(from: location)
        let gps = result[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        #expect(gps?[kCGImagePropertyGPSLatitudeRef as String] as? String == "S")
        #expect(gps?[kCGImagePropertyGPSLongitudeRef as String] as? String == "W")
        #expect(gps?[kCGImagePropertyGPSLatitude as String] as? Double == 33.8688)
        #expect(gps?[kCGImagePropertyGPSLongitude as String] as? Double == 70.6483)
    }

    @Test
    func `Zero coordinates resolve to N/E refs as the boundary case`() {
        let location = DomainLocation(latitude: 0, longitude: 0)
        let result = ExifGPSBuilder.metadata(from: location)
        let gps = result[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        #expect(gps?[kCGImagePropertyGPSLatitudeRef as String] as? String == "N")
        #expect(gps?[kCGImagePropertyGPSLongitudeRef as String] as? String == "E")
        #expect(gps?[kCGImagePropertyGPSLatitude as String] as? Double == 0)
        #expect(gps?[kCGImagePropertyGPSLongitude as String] as? Double == 0)
    }

    @Test
    func `Timestamp encodes as ISO8601 with internet date time and round-trips back to same instant`() {
        let instant = Date(timeIntervalSince1970: 1_700_000_000)
        let location = DomainLocation(latitude: 10, longitude: 20)
        let result = ExifGPSBuilder.metadata(from: location, timestamp: instant)
        let gps = result[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        let stamp = gps?[kCGImagePropertyGPSTimeStamp as String] as? String
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        let parsed = stamp.flatMap { parser.date(from: $0) }
        #expect(parsed == instant)
    }
}
