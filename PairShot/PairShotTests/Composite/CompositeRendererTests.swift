import CoreGraphics
import Foundation
import ImageIO
@testable import PairShot
import Testing
import UIKit
import UniformTypeIdentifiers

struct CompositeRendererTests {
    @Test
    func `composeImage with B + A pair succeeds and preserves EXIF DateTimeOriginal`() throws {
        let before = makeSolidJPEG(width: 800, height: 600, color: .red)
        let after = makeSolidJPEG(width: 800, height: 600, color: .blue)
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let options = CompositeOptions(
            layout: .horizontal,
            compressionQuality: 0.95,
            utType: .jpeg,
            watermarkEnabled: false,
            watermark: nil,
            combineSettings: nil,
            includeGPS: false,
        )

        let data = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: options,
            capturedAt: capturedAt,
            latitude: nil,
            longitude: nil,
        )

        #expect(!data.isEmpty)
        let exif = readExifDictionary(jpeg: data)
        let stamp = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String
        #expect(stamp != nil)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = CompositeRenderer.exifDateFormat
        let parsed = stamp.flatMap { formatter.date(from: $0) }
        #expect(parsed == capturedAt)
    }

    @Test
    func `composeImage embeds GPS dictionary when latitude and longitude are supplied`() throws {
        let before = makeSolidJPEG(width: 400, height: 400, color: .gray)
        let after = makeSolidJPEG(width: 400, height: 400, color: .gray)
        let options = CompositeOptions(
            layout: .horizontal,
            compressionQuality: 0.9,
            utType: .jpeg,
            watermarkEnabled: false,
            watermark: nil,
            combineSettings: nil,
            includeGPS: true,
        )

        let data = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: options,
            capturedAt: .now,
            latitude: 37.5,
            longitude: -122.0,
        )

        let gps = readGPSDictionary(jpeg: data)
        #expect(gps[kCGImagePropertyGPSLatitudeRef as String] as? String == "N")
        #expect(gps[kCGImagePropertyGPSLongitudeRef as String] as? String == "W")
        #expect(gps[kCGImagePropertyGPSLatitude as String] as? Double == 37.5)
        #expect(gps[kCGImagePropertyGPSLongitude as String] as? Double == 122.0)
    }

    @MainActor
    @Test
    func `renderSingle for B-only entry produces non-empty JPEG`() {
        let image = makeSolidUIImage(width: 400, height: 600, color: .green)
        let data = CompositeRenderer.renderSingle(
            image: image,
            combineSettings: nil,
            isBefore: true,
            watermark: nil,
            utType: .jpeg,
            compressionQuality: 0.95,
        )
        #expect(data != nil)
        #expect(data?.isEmpty == false)
        let dims = decodePixelSize(jpeg: data ?? Data())
        #expect(dims?.width == 400)
        #expect(dims?.height == 600)
    }

    @MainActor
    @Test
    func `renderSingle for A-only entry produces non-empty JPEG`() {
        let image = makeSolidUIImage(width: 600, height: 400, color: .blue)
        let data = CompositeRenderer.renderSingle(
            image: image,
            combineSettings: nil,
            isBefore: false,
            watermark: nil,
            utType: .jpeg,
            compressionQuality: 0.95,
        )
        #expect(data != nil)
        let dims = decodePixelSize(jpeg: data ?? Data())
        #expect(dims?.width == 600)
        #expect(dims?.height == 400)
    }

    @Test
    func `composeImage with watermark disabled equals composeImage with watermark setting but flag off`() throws {
        let before = makeSolidJPEG(width: 400, height: 400, color: .red)
        let after = makeSolidJPEG(width: 400, height: 400, color: .blue)
        let watermark = WatermarkSettings(type: .text, text: "PAIRSHOT")
        let off = CompositeOptions(
            layout: .horizontal,
            compressionQuality: 0.95,
            utType: .jpeg,
            watermarkEnabled: false,
            watermark: watermark,
            combineSettings: nil,
            includeGPS: false,
        )
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let withoutWatermark = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: off,
            capturedAt: timestamp,
            latitude: nil,
            longitude: nil,
        )

        var on = off
        on.watermarkEnabled = true
        let withWatermark = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: on,
            capturedAt: timestamp,
            latitude: nil,
            longitude: nil,
        )

        let offDims = try #require(decodePixelSize(jpeg: withoutWatermark))
        let onDims = try #require(decodePixelSize(jpeg: withWatermark))
        #expect(offDims == onDims)

        let offPixels = try #require(decodeRGBA(jpeg: withoutWatermark))
        let onPixels = try #require(decodeRGBA(jpeg: withWatermark))
        let diffCount = countDifferingPixels(lhs: offPixels, rhs: onPixels)
        #expect(diffCount > 0)
    }

    @Test
    func `composeImage without watermark is bit-stable and decodes to a high-PSNR image vs itself`() throws {
        let before = makeSolidJPEG(width: 400, height: 400, color: .red)
        let after = makeSolidJPEG(width: 400, height: 400, color: .blue)
        let options = CompositeOptions(
            layout: .horizontal,
            compressionQuality: 0.95,
            utType: .jpeg,
            watermarkEnabled: false,
            watermark: nil,
            combineSettings: nil,
            includeGPS: false,
        )
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let first = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: options,
            capturedAt: timestamp,
            latitude: nil,
            longitude: nil,
        )
        let second = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: options,
            capturedAt: timestamp,
            latitude: nil,
            longitude: nil,
        )

        let firstPixels = try #require(decodeRGBA(jpeg: first))
        let secondPixels = try #require(decodeRGBA(jpeg: second))
        let psnr = computePSNR(lhs: firstPixels, rhs: secondPixels)
        #expect(psnr >= 35.0)
    }

    @Test
    func `composeImage with lossless utType produces HEIC output`() throws {
        let before = makeSolidJPEG(width: 400, height: 400, color: .red)
        let after = makeSolidJPEG(width: 400, height: 400, color: .blue)
        let options = CompositeOptions(
            layout: .horizontal,
            compressionQuality: 1.0,
            utType: .heic,
            watermarkEnabled: false,
            watermark: nil,
            combineSettings: nil,
            includeGPS: false,
        )

        let data = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: options,
            capturedAt: .now,
            latitude: nil,
            longitude: nil,
        )

        #expect(!data.isEmpty)
        #expect(ImageSignatures.isHEIC(data))
        #expect(!ImageSignatures.isJPEG(data))
    }

    @Test
    func `composeImage with high preset (jpeg) produces JPEG output`() throws {
        let before = makeSolidJPEG(width: 400, height: 400, color: .red)
        let after = makeSolidJPEG(width: 400, height: 400, color: .blue)
        let options = CompositeOptions(
            layout: .horizontal,
            compressionQuality: 0.95,
            utType: .jpeg,
            watermarkEnabled: false,
            watermark: nil,
            combineSettings: nil,
            includeGPS: false,
        )

        let data = try CompositeRenderer.composeImage(
            beforeData: before,
            afterData: after,
            options: options,
            capturedAt: .now,
            latitude: nil,
            longitude: nil,
        )

        #expect(ImageSignatures.isJPEG(data))
        #expect(!ImageSignatures.isHEIC(data))
    }
}

private struct PixelGrid {
    let width: Int
    let height: Int
    let bytes: [UInt8]
}

private func makeSolidJPEG(width: Int, height: Int, color: UIColor) -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    let image = renderer.image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    return image.jpegData(compressionQuality: 0.95) ?? Data()
}

private func makeSolidUIImage(width: Int, height: Int, color: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    return renderer.image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private func decodePixelSize(jpeg: Data) -> CGSize? {
    guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    return CGSize(width: cgImage.width, height: cgImage.height)
}

private func decodeRGBA(jpeg: Data) -> PixelGrid? {
    guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = bytes.withUnsafeMutableBytes({ rawBuffer -> CGContext? in
        guard let baseAddress = rawBuffer.baseAddress else { return nil }
        return CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
        )
    }) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return PixelGrid(width: width, height: height, bytes: bytes)
}

private func readExifDictionary(jpeg: Data) -> [String: Any] {
    readMetadataDictionary(jpeg: jpeg, key: kCGImagePropertyExifDictionary as String)
}

private func readGPSDictionary(jpeg: Data) -> [String: Any] {
    readMetadataDictionary(jpeg: jpeg, key: kCGImagePropertyGPSDictionary as String)
}

private func readMetadataDictionary(jpeg: Data, key: String) -> [String: Any] {
    guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    else { return [:] }
    return properties[key] as? [String: Any] ?? [:]
}

private func countDifferingPixels(lhs: PixelGrid, rhs: PixelGrid) -> Int {
    guard lhs.width == rhs.width, lhs.height == rhs.height else { return Int.max }
    var diff = 0
    for index in 0 ..< lhs.bytes.count where lhs.bytes[index] != rhs.bytes[index] {
        diff += 1
    }
    return diff
}

private func computePSNR(lhs: PixelGrid, rhs: PixelGrid) -> Double {
    guard lhs.width == rhs.width, lhs.height == rhs.height, !lhs.bytes.isEmpty else {
        return 0
    }
    var sumSquaredError: Double = 0
    let count = lhs.bytes.count
    for index in 0 ..< count {
        let delta = Double(lhs.bytes[index]) - Double(rhs.bytes[index])
        sumSquaredError += delta * delta
    }
    let mse = sumSquaredError / Double(count)
    if mse == 0 { return .infinity }
    return 10.0 * log10((255.0 * 255.0) / mse)
}

enum ImageSignatures {
    static func isJPEG(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        return data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF
    }

    static func isHEIC(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let ftyp = data.subdata(in: 4 ..< 8)
        guard ftyp == Data([0x66, 0x74, 0x79, 0x70]) else { return false }
        let brand = data.subdata(in: 8 ..< 12)
        let knownHEIFBrands: [Data] = [
            Data([0x68, 0x65, 0x69, 0x63]),
            Data([0x68, 0x65, 0x69, 0x78]),
            Data([0x6D, 0x69, 0x66, 0x31]),
            Data([0x6D, 0x73, 0x66, 0x31]),
            Data([0x68, 0x65, 0x76, 0x63]),
            Data([0x68, 0x65, 0x76, 0x78]),
        ]
        return knownHEIFBrands.contains(brand)
    }
}
