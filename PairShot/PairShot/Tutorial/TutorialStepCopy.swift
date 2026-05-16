import Foundation

enum TutorialStepCopy {
    static func text(for step: TutorialStep) -> String {
        switch step {
            case .homeCaptureHighlight: "여기를 눌러 촬영을 시작하세요"
            case .captureGuidePortrait: "세로 모드로 촬영하세요"
            case .captureGuideLeft: "좌측 가이드에 맞춰 촬영하세요"
            case .captureGuideRight: "우측 가이드에 맞춰 촬영하세요"
            case .backToHome: "홈으로 돌아가세요"
            case .tapPairCard: "촬영한 페어 카드를 눌러 보세요"
            case .afterCameraGuide: "After 사진을 촬영하세요"
            case .backToHome2: "홈으로 돌아가세요"
            case .enterSelectionMode: "선택 모드로 진입하세요"
            case .selectionShare: "선택한 페어를 공유하세요"
            case .selectionSave: "선택한 페어를 저장하세요"
            case .selectionDelete: "선택한 페어를 삭제할 수 있어요"
            case .selectionExport: "선택한 페어를 내보낼 수 있어요"
            case .saveToDevice: "기기에 저장할 수 있어요"
            case .goSettings: "설정에서 더 많은 옵션을 확인하세요"
            case .done: ""
        }
    }
}
