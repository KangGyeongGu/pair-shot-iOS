import Foundation

enum TutorialStepCopy {
    static func text(for step: TutorialStep) -> String {
        switch step {
            case .captureGuidePortrait: "세로로 들고 촬영해 보세요"
            case .captureGuideLeft: "왼쪽으로 돌려 가로로 촬영하세요"
            case .captureGuideRight: "오른쪽으로 돌려 가로로 촬영하세요"
            case .backToHome: "홈 버튼을 눌러 돌아가세요"
            case .tapPairCard: "방금 촬영한 페어 카드를 눌러 보세요"
            case .afterCameraGuide: "방금 찍은 사진의 오버레이와 회전 가이드를 따라 AFTER 촬영을 완료해주세요"
            case .afterCameraInProgress: ""
            case .backToHome2: "홈으로 돌아가세요"
            case .enterSelectionMode: "여기를 눌러 선택 모드로 들어가세요"
            case .selectionShare: "SNS, 메신저 등으로 공유하세요"
            case .selectionSave: "기기 갤러리 또는 지정 위치에 저장하세요"
            case .selectionDelete: "선택한 사진을 삭제하세요"
            case .selectionExport: "다양한 내보내기 옵션을 설정할 수 있어요"
            case .goSettings: "설정에서 더 많은 옵션을 확인하세요"
            case .done: "설정에서 기본 옵션을 조정할 수 있어요. 튜토리얼을 마칠게요."
        }
    }
}
