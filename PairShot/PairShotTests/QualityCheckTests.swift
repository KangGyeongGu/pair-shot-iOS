import CoreImage
@testable import PairShot
import Testing
import UIKit

struct QualityCheckTests {
    @Test @MainActor func analyze_sharpImage_returnsNil() async {
        let service = QualityCheckService()
        let image = createTestImage(pattern: .highContrast)
        let issue = await service.analyze(image, isLowLight: true)
        // Reveal actual issue for debugging
        #expect(issue == nil, "Expected no quality issue but got: \(String(describing: issue))")
    }

    private func createTestImage(pattern: TestPattern) -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            switch pattern {
                case .highContrast:
                    let darkGray = UIColor(white: 0.25, alpha: 1.0).cgColor
                    let lightGray = UIColor(white: 0.75, alpha: 1.0).cgColor
                    for x in 0 ..< 200 {
                        ctx.cgContext.setFillColor(x % 2 == 0 ? lightGray : darkGray)
                        ctx.cgContext.fill(CGRect(x: x, y: 0, width: 1, height: 200))
                    }
                case .uniform:
                    ctx.cgContext.setFillColor(UIColor.gray.cgColor)
                    ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            }
        }
    }

    enum TestPattern {
        case highContrast
        case uniform
    }
}
