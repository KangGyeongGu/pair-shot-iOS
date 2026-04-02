import SwiftUI

extension CameraView {
    func runQualityCheck(on image: UIImage) {
        Task {
            let issue = await qualityCheckService.analyze(image, isLowLight: lowLightManager.isTorchActive)
            guard let issue else { return }
            switch issue {
                case .blurry:
                    qualityIssueMessage = "흐린 사진이 감지되었습니다. 재촬영하시겠습니까?"
                case .overExposed:
                    qualityIssueMessage = "과다 노출이 감지되었습니다. 재촬영하시겠습니까?"
                case .underExposed:
                    qualityIssueMessage = "노출 부족이 감지되었습니다. 재촬영하시겠습니까?"
            }
            showQualityAlert = true
        }
    }
}
