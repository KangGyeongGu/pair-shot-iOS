import CoreGraphics
import Foundation
import ImageIO
@testable import PairShot
import Testing
import UniformTypeIdentifiers

struct AspectRatioCycleTests {
    @Test
    func `AspectRatio.next cycles 4:3 -> 16:9 -> 1:1 -> 4:3`() {
        #expect(AspectRatio.fourThree.next == .sixteenNine)
        #expect(AspectRatio.sixteenNine.next == .square)
        #expect(AspectRatio.square.next == .fourThree)
    }

    @Test
    func `AspectRatio.label matches rawValue`() {
        #expect(AspectRatio.fourThree.label == "4:3")
        #expect(AspectRatio.sixteenNine.label == "16:9")
        #expect(AspectRatio.square.label == "1:1")
    }

    @Test
    func `portraitHeightMultiplier matches the long edge ratio`() {
        #expect(abs(AspectRatio.fourThree.portraitHeightMultiplier - 4.0 / 3.0) < 0.0001)
        #expect(abs(AspectRatio.sixteenNine.portraitHeightMultiplier - 16.0 / 9.0) < 0.0001)
        #expect(abs(AspectRatio.square.portraitHeightMultiplier - 1.0) < 0.0001)
    }
}

struct CameraSettingsAspectRatioCompatibilityTests {
    @Test
    func `CameraSettings without aspectRatio resolves to .fourThree`() {
        let settings = CameraSettings(zoomFactor: 1.0, lensPosition: .backWide)
        #expect(settings.aspectRatio == nil)
        #expect(settings.resolvedAspectRatio == .fourThree)
    }

    @Test
    func `CameraSettings round-trips aspectRatio via Codable`() throws {
        let settings = CameraSettings(
            zoomFactor: 1.5,
            lensPosition: .backUltraWide,
            aspectRatio: .sixteenNine,
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)
        #expect(decoded.aspectRatio == .sixteenNine)
        #expect(decoded.resolvedAspectRatio == .sixteenNine)
    }

    @Test
    func `Legacy JSON without aspectRatio decodes with nil and resolves to fourThree`() throws {
        let raw = #"{"zoomFactor":1.0,"lensPosition":"backWide"}"#
        let decoded = try JSONDecoder().decode(CameraSettings.self, from: Data(raw.utf8))
        #expect(decoded.aspectRatio == nil)
        #expect(decoded.resolvedAspectRatio == .fourThree)
    }
}

@MainActor
struct CameraLayoutMathSlotTests {
    private let iphone15Pro = CGSize(width: 393, height: 793)
    private let iphoneSE = CGSize(width: 375, height: 647)

    @Test
    func `Slot is always 4:3 of width regardless of aspect`() {
        for aspect in AspectRatio.allCases {
            let layout = CameraLayoutMath.compute(
                totalSize: iphone15Pro,
                isAdFree: true,
                aspect: aspect,
            )
            #expect(layout.slotWidth == iphone15Pro.width)
            #expect(abs(layout.slotHeight - iphone15Pro.width * 4.0 / 3.0) < 0.0001)
        }
    }

    @Test
    func `4:3 preview fills slot exactly with zero insets`() {
        let layout = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .fourThree,
        )
        #expect(layout.previewWidth == layout.slotWidth)
        #expect(layout.previewHeight == layout.slotHeight)
        #expect(layout.previewLeadingInsetInSlot == 0)
        #expect(layout.previewTopInsetInSlot == 0)
    }

    @Test
    func `1:1 preview is a centered square inside the 4:3 slot`() {
        let layout = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .square,
        )
        #expect(layout.previewWidth == layout.slotWidth)
        #expect(layout.previewHeight == layout.slotWidth)
        #expect(layout.previewLeadingInsetInSlot == 0)
        let expectedTop = (layout.slotHeight - layout.slotWidth) / 2
        #expect(abs(layout.previewTopInsetInSlot - expectedTop) < 0.0001)
    }

    @Test
    func `16:9 portrait preview is centered horizontally inside the 4:3 slot`() {
        let layout = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .sixteenNine,
        )
        #expect(abs(layout.previewHeight - layout.slotHeight) < 0.0001)
        let expectedWidth = layout.slotHeight * 9.0 / 16.0
        #expect(abs(layout.previewWidth - expectedWidth) < 0.0001)
        #expect(layout.previewTopInsetInSlot == 0)
        let expectedLeading = (layout.slotWidth - expectedWidth) / 2
        #expect(abs(layout.previewLeadingInsetInSlot - expectedLeading) < 0.0001)
    }

    @Test
    func `Strip and shutter zones split remaining space at the design ratio`() {
        for aspect in AspectRatio.allCases {
            let layout = CameraLayoutMath.compute(
                totalSize: iphone15Pro,
                isAdFree: true,
                aspect: aspect,
            )
            let remaining = iphone15Pro.height - layout.slotHeight
            let expectedStrip = remaining * CameraLayoutMath.stripZoneRatio
            let expectedShutter = remaining - expectedStrip
            #expect(abs(layout.stripHeight - expectedStrip) < 0.0001)
            #expect(abs(layout.shutterHeight - expectedShutter) < 0.0001)
        }
    }

    @Test
    func `Slot, strip, and shutter zones cover the full total height`() {
        let layout = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .fourThree,
        )
        let sum = layout.slotHeight + layout.stripHeight + layout.shutterHeight
        #expect(abs(sum - iphone15Pro.height) < 0.0001)
    }

    @Test
    func `Aspect change does not move slot, strip, or shutter zones`() {
        let fourThree = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .fourThree,
        )
        let square = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .square,
        )
        let sixteenNine = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .sixteenNine,
        )

        #expect(fourThree.slotHeight == square.slotHeight)
        #expect(fourThree.slotHeight == sixteenNine.slotHeight)
        #expect(fourThree.stripHeight == square.stripHeight)
        #expect(fourThree.stripHeight == sixteenNine.stripHeight)
        #expect(fourThree.shutterHeight == square.shutterHeight)
        #expect(fourThree.shutterHeight == sixteenNine.shutterHeight)
    }

    @Test
    func `Banner height does not affect zone math`() {
        let withBanner = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: false,
            aspect: .fourThree,
        )
        let withoutBanner = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .fourThree,
        )
        #expect(withBanner.slotHeight == withoutBanner.slotHeight)
        #expect(withBanner.stripHeight == withoutBanner.stripHeight)
        #expect(withBanner.shutterHeight == withoutBanner.shutterHeight)
        #expect(withBanner.bannerHeight > 0)
        #expect(withoutBanner.bannerHeight == 0)
    }

    @Test
    func `iPhone SE proportionally shrinks strip and shutter zones`() {
        let layout = CameraLayoutMath.compute(
            totalSize: iphoneSE,
            isAdFree: true,
            aspect: .fourThree,
        )
        #expect(abs(layout.slotHeight - iphoneSE.width * 4.0 / 3.0) < 0.0001)
        let remaining = iphoneSE.height - layout.slotHeight
        let expectedStrip = remaining * CameraLayoutMath.stripZoneRatio
        #expect(abs(layout.stripHeight - expectedStrip) < 0.0001)
        #expect(layout.stripHeight < 168)
        #expect(layout.shutterHeight < 116)
    }

    @Test
    func `Pro Max sized device produces larger zones than 15 Pro`() {
        let proMax = CGSize(width: 440, height: 894)
        let layout = CameraLayoutMath.compute(
            totalSize: proMax,
            isAdFree: true,
            aspect: .fourThree,
        )
        let baseline = CameraLayoutMath.compute(
            totalSize: iphone15Pro,
            isAdFree: true,
            aspect: .fourThree,
        )
        #expect(layout.slotHeight > baseline.slotHeight)
        #expect(layout.stripHeight > baseline.stripHeight)
        #expect(layout.shutterHeight > baseline.shutterHeight)
    }
}

@MainActor
struct StripDesignProportionalTests {
    @Test
    func `cardHeight reproduces legacy 134pt at the original 168pt strip`() {
        #expect(abs(StripDesign.cardHeight(stripHeight: 168) - 134) < 0.0001)
    }

    @Test
    func `cardHeight scales linearly with strip height`() {
        let h168 = StripDesign.cardHeight(stripHeight: 168)
        let h84 = StripDesign.cardHeight(stripHeight: 84)
        #expect(abs(h84 - h168 / 2) < 0.0001)
    }

    @Test
    func `cardWidth maintains card aspect ratio at any strip height`() {
        let w168 = StripDesign.cardWidth(stripHeight: 168)
        let h168 = StripDesign.cardHeight(stripHeight: 168)
        #expect(abs(w168 / h168 - 100.0 / 134.0) < 0.0001)

        let w84 = StripDesign.cardWidth(stripHeight: 84)
        let h84 = StripDesign.cardHeight(stripHeight: 84)
        #expect(abs(w84 / h84 - 100.0 / 134.0) < 0.0001)
    }

    @Test
    func `Zero or negative strip height yields zero card dimensions`() {
        #expect(StripDesign.cardHeight(stripHeight: 0) == 0)
        #expect(StripDesign.cardWidth(stripHeight: 0) == 0)
        #expect(StripDesign.cardHeight(stripHeight: -50) == 0)
        #expect(StripDesign.paddingVertical(stripHeight: 0) == 0)
    }
}

struct AspectRatioCropperTests {
    @Test
    func `4:3 input passes through unchanged`() {
        let original = makeTestJPEG(width: 3000, height: 4000)
        let cropped = AspectRatioCropper.cropToAspect(
            data: original,
            targetAspect: .fourThree,
            utType: .jpeg,
        )
        #expect(cropped == original)
    }

    @Test
    func `16:9 portrait crop produces 9:16 image data with reduced height`() {
        let source = makeTestJPEG(width: 3000, height: 4000)
        let cropped = AspectRatioCropper.cropToAspect(
            data: source,
            targetAspect: .sixteenNine,
            utType: .jpeg,
        )
        let dims = decodePixelSize(jpeg: cropped)
        guard let dims else {
            Issue.record("Failed to decode cropped jpeg")
            return
        }
        let ratio = dims.width / dims.height
        let expected: CGFloat = 9.0 / 16.0
        #expect(abs(ratio - expected) < 0.01)
    }

    @Test
    func `1:1 crop on a portrait image yields a square`() {
        let source = makeTestJPEG(width: 3000, height: 4000)
        let cropped = AspectRatioCropper.cropToAspect(
            data: source,
            targetAspect: .square,
            utType: .jpeg,
        )
        let dims = decodePixelSize(jpeg: cropped)
        guard let dims else {
            Issue.record("Failed to decode cropped jpeg")
            return
        }
        #expect(abs(dims.width - dims.height) < 2)
    }

    @Test
    func `centerCropRect for 16:9 portrait centers horizontally and produces 9:16 area`() {
        let rect = AspectRatioCropper.centerCropRect(
            imageWidth: 3000,
            imageHeight: 4000,
            targetAspect: .sixteenNine,
        )
        let expectedWidth = 4000.0 * 9.0 / 16.0
        #expect(abs(rect.width - expectedWidth) < 1.5)
        #expect(abs(rect.height - 4000.0) < 0.0001)
        let isHorizontallyCentered = abs(rect.origin.x * 2 + rect.width - 3000) < 2
        #expect(isHorizontallyCentered)
        #expect(abs(rect.origin.y) < 0.0001)
    }

    @Test
    func `HEIC input cropped to 16:9 produces HEIC output`() {
        let source = makeTestHEIC(width: 1024, height: 768)
        guard !source.isEmpty else {
            Issue.record("Failed to create HEIC source")
            return
        }
        let cropped = AspectRatioCropper.cropToAspect(
            data: source,
            targetAspect: .sixteenNine,
            utType: .heic,
        )
        #expect(isHEIC(cropped))
        #expect(!isJPEG(cropped))
    }

    @Test
    func `JPEG input cropped to 16:9 produces JPEG output`() {
        let source = makeTestJPEG(width: 1024, height: 768)
        let cropped = AspectRatioCropper.cropToAspect(
            data: source,
            targetAspect: .sixteenNine,
            utType: .jpeg,
        )
        #expect(isJPEG(cropped))
        #expect(!isHEIC(cropped))
    }
}

private func makeTestHEIC(width: Int, height: Int) -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitsPerComponent = 8
    let bytesPerRow = width * 4
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    ) else { return Data() }
    context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else { return Data() }
    let mutable = NSMutableData()
    let identifier = UTType.heic.identifier as CFString
    guard let dest = CGImageDestinationCreateWithData(mutable, identifier, 1, nil) else {
        return Data()
    }
    CGImageDestinationAddImage(dest, image, [
        kCGImageDestinationLossyCompressionQuality: 1.0,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return Data() }
    return mutable as Data
}

private func isJPEG(_ data: Data) -> Bool {
    guard data.count >= 3 else { return false }
    return data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF
}

private func isHEIC(_ data: Data) -> Bool {
    guard data.count >= 12 else { return false }
    let ftyp = data.subdata(in: 4 ..< 8)
    return ftyp == Data([0x66, 0x74, 0x79, 0x70])
}

private func makeTestJPEG(width: Int, height: Int) -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitsPerComponent = 8
    let bytesPerRow = width * 4
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    ) else {
        return Data()
    }
    context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else { return Data() }
    let mutable = NSMutableData()
    let identifier = "public.jpeg" as CFString
    guard let dest = CGImageDestinationCreateWithData(mutable, identifier, 1, nil) else {
        return Data()
    }
    CGImageDestinationAddImage(dest, image, [
        kCGImageDestinationLossyCompressionQuality: 0.95,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return Data() }
    return mutable as Data
}

private func decodePixelSize(jpeg: Data) -> CGSize? {
    guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    return CGSize(width: cgImage.width, height: cgImage.height)
}
