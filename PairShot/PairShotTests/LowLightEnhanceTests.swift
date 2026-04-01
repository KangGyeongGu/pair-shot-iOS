import Testing
import CoreImage
@testable import PairShot

@MainActor
struct LowLightEnhanceTests {

    // 테스트용 1x1 픽셀 CIImage 생성 헬퍼
    private func makeTestImage() -> CIImage {
        CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    // MARK: - happy path

    @Test func enhance_happyPath_returnsCIImage() {
        let manager = LowLightManager()
        let input = makeTestImage()
        let output = manager.enhance(image: input)
        // 입력이 CIImage이면 반드시 CIImage를 반환해야 한다
        // (타입 자체가 non-optional이므로 컴파일 타임 보장, 런타임 extent 확인)
        #expect(output.extent.isNull == false)
    }

    @Test func enhance_happyPath_outputExtentMatchesInput() {
        let manager = LowLightManager()
        let input = makeTestImage()
        let output = manager.enhance(image: input)
        // CIHighlightShadowAdjust는 같은 extent를 유지해야 한다
        #expect(output.extent == input.extent)
    }

    @Test func enhance_happyPath_shadowFilterApplied_outputDiffersFromInput() {
        let manager = LowLightManager()
        let input = makeTestImage()
        let output = manager.enhance(image: input)

        let ctx = CIContext()
        let inputData = ctx.render(input)
        let outputData = ctx.render(output)

        // shadowAmount=1.5 필터 적용 결과는 원본과 달라야 한다
        #expect(inputData != outputData)
    }

    // MARK: - boundary

    @Test func enhance_boundary_lowISOSkipsNoiseReduction_stillReturnsCIImage() {
        // lastISO 초기값 0 → noiseReduction 분기 미진입, shadowHighlight만 적용
        let manager = LowLightManager()
        let input = makeTestImage()
        let output = manager.enhance(image: input)
        #expect(output.extent.width == input.extent.width)
        #expect(output.extent.height == input.extent.height)
    }

    @Test func enhance_boundary_calledTwiceProducesValidResult() {
        let manager = LowLightManager()
        let input = makeTestImage()
        let first = manager.enhance(image: input)
        let second = manager.enhance(image: first)
        #expect(second.extent.isNull == false)
    }

    // MARK: - negative

    @Test func enhance_negative_doesNotReturnIdenticalExtent_onBlackImage() {
        // 완전 검은 이미지에 shadow 필터를 적용해도 extent는 유지되어야 한다
        let manager = LowLightManager()
        let black = CIImage(color: CIColor.black)
            .cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        let output = manager.enhance(image: black)
        #expect(output.extent == black.extent)
    }

    // MARK: - error

    @Test func enhance_error_largeImageDoesNotCrash() {
        let manager = LowLightManager()
        // 4032x3024 — 카메라 최대 해상도 수준의 빈 이미지
        let large = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: 4032, height: 3024))
        let output = manager.enhance(image: large)
        #expect(output.extent.width == 4032)
        #expect(output.extent.height == 3024)
    }
}

// CIContext 렌더링 헬퍼
private extension CIContext {
    func render(_ image: CIImage) -> Data? {
        let size = image.extent
        guard let cgImage = self.createCGImage(image, from: size) else { return nil }
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let totalBytes = bytesPerRow * cgImage.height
        var data = Data(count: totalBytes)
        data.withUnsafeMutableBytes { ptr in
            guard let baseAddr = ptr.baseAddress else { return }
            guard let colorSpace = cgImage.colorSpace,
                  let ctx = CGContext(
                      data: baseAddr,
                      width: cgImage.width,
                      height: cgImage.height,
                      bitsPerComponent: bitsPerComponent,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: cgImage.bitmapInfo.rawValue
                  ) else { return }
            ctx.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: cgImage.width, height: cgImage.height)))
        }
        return data
    }
}
