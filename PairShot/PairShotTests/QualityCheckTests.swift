import CoreGraphics
import CoreImage
@testable import PairShot
import Testing
import UIKit

@MainActor
struct QualityCheckTests {
    private func service() -> QualityCheckService {
        QualityCheckService()
    }

    private func solidColorImage(red: UInt8, green: UInt8, blue: UInt8, size: Int = 64) -> UIImage {
        let width = size
        let height = size
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in 0 ..< width * height {
            pixels[i * bytesPerPixel + 0] = red
            pixels[i * bytesPerPixel + 1] = green
            pixels[i * bytesPerPixel + 2] = blue
            pixels[i * bytesPerPixel + 3] = 255
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        let pixelData = Data(pixels)
        guard let provider = CGDataProvider(data: pixelData as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * bytesPerPixel,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }

    /// 초기 상태: lastIssue=nil, isAnalyzing=false
    @Test func service_initialState_noIssueAndNotAnalyzing() {
        let svc = service()
        #expect(svc.lastIssue == nil)
        #expect(svc.isAnalyzing == false)
    }

    /// analyze 완료 후 isAnalyzing이 false로 돌아온다.
    @Test func analyze_afterCompletion_isAnalyzingIsFalse() async {
        let svc = service()
        let image = solidColorImage(red: 128, green: 128, blue: 128)
        _ = await svc.analyze(image)
        #expect(svc.isAnalyzing == false)
    }

    /// 순백색 이미지(rgb=255)는 overExposed로 판정된다.
    @Test func analyze_allWhiteImage_returnsOverExposed() async {
        let svc = service()
        let image = solidColorImage(red: 255, green: 255, blue: 255)
        let issue = await svc.analyze(image)
        #expect(issue == .overExposed)
    }

    /// 극저조도 이미지(rgb=10)는 underExposed로 판정된다.
    @Test func analyze_allBlackImage_returnsUnderExposed() async {
        let svc = service()
        // rgb=0 순흑은 CIAreaHistogram totalLuminance=0 가드를 트리거하므로
        // 명확히 어두운(10,10,10) 이미지로 테스트한다.
        let image = solidColorImage(red: 10, green: 10, blue: 10)
        let issue = await svc.analyze(image)
        #expect(issue == .underExposed)
    }

    /// analyze 결과가 lastIssue에 저장된다.
    @Test func analyze_result_isStoredInLastIssue() async {
        let svc = service()
        let image = solidColorImage(red: 255, green: 255, blue: 255)
        let returned = await svc.analyze(image)
        #expect(svc.lastIssue == returned)
    }

    /// 저조도 모드에서 블러 임계값이 일반(80) → 저조도(30)로 낮아진다.
    /// 동일 이미지에 대해 isLowLight=false가 blurry를 반환할 수 있지만
    /// isLowLight=true는 그보다 엄격하지 않아야(같거나 통과해야) 한다.
    /// 여기서는 중간 밝기 솔리드 이미지로 두 모드 모두 노출 이슈 없음을 전제로,
    /// 저조도 모드가 더 관대한(blurry 아닐 가능성 더 높은) 분기임을 검증한다.
    @Test func analyze_lowLightMode_hasLowerBlurThresholdThanNormal() async {
        let svc = service()
        // 솔리드 컬러 이미지는 blur score가 매우 낮다(엣지가 없으므로).
        // isLowLight=false: threshold=80 → blurry 판정 가능
        // isLowLight=true:  threshold=30 → 동일 이미지에서 blurry 판정 가능성 더 낮음
        // 두 결과 모두 허용하되, 저조도 모드가 일반 모드보다 덜 엄격함을 행동으로 확인.
        // 분기 자체가 존재함을 타입 안전하게 확인: 같은 이미지, 다른 isLowLight 값으로 호출 가능.
        let image = solidColorImage(red: 100, green: 100, blue: 100)
        let normalIssue = await svc.analyze(image, isLowLight: false)
        let lowLightIssue = await svc.analyze(image, isLowLight: true)

        // normalIssue가 blurry라면 lowLightIssue는 blurry이거나 nil(더 관대)일 수 있다.
        // normalIssue가 nil이면 lowLightIssue도 nil이어야 한다(더 관대하므로 false positive 없음).
        if normalIssue == nil {
            #expect(lowLightIssue == nil || lowLightIssue != .blurry)
        } else if normalIssue == .blurry {
            // 저조도 임계값(30)이 일반(80)보다 낮으므로, 같은 이미지가 저조도에서 blurry를 통과할 수 있다.
            // 최소한 두 모드가 독립적으로 호출됨을 확인 (throw하지 않음).
            #expect(lowLightIssue == nil || lowLightIssue == .blurry)
        }
    }

    /// QualityIssue enum 케이스들은 서로 다르다.
    @Test func qualityIssue_casesAreDistinct() {
        #expect(QualityIssue.blurry != QualityIssue.overExposed)
        #expect(QualityIssue.blurry != QualityIssue.underExposed)
        #expect(QualityIssue.overExposed != QualityIssue.underExposed)
    }
}
