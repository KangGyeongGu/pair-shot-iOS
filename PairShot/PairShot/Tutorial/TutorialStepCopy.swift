import Foundation

enum TutorialStepCopy {
    static func text(for step: TutorialStep) -> String {
        switch step {
            case .captureGuidePortrait: "기기를 세로로 들어 촬영해주세요."
            case .captureGuideLeft: "기기를 좌측으로 회전해 가로로 촬영해주세요."
            case .captureGuideRight: "기기를 우측으로 회전해 가로로 촬영해주세요."
            case .backToHome: "홈 화면으로 이동합니다."
            case .tapPairCard: "방금 촬영한 페어 카드를 눌러 보세요."
            case .afterCameraStrip: "BEFORE 사진들을 이곳에서 확인할 수 있어요."
            case .afterCameraStripLongPressHint: "활성 카드를 길게 누르면 BEFORE 사진을 크게 볼 수 있어요."
            case .afterCameraGuide: "방금 찍은 사진의 오버레이와 회전 가이드를 따라 AFTER 촬영을 완료해주세요."
            case .afterCameraInProgress: ""
            case .backToHome2: "홈 화면으로 이동합니다."
            case .enterSelectionMode: "버튼을 눌러 선택 모드로 진입하세요."
            case .selectionShare: "SNS, 메신저 등으로 공유하세요."
            case .selectionSave: "기기 갤러리 또는 지정한 위치에 저장하세요."
            case .selectionDelete: "선택한 사진을 삭제하세요."
            case .selectionExport: "다양한 내보내기 옵션을 설정할 수 있어요."
            case .goSettings: "설정에서 더 많은 옵션을 확인하세요."
            case .done: "설정에서 기본 옵션을 조정할 수 있어요. 튜토리얼을 마칠게요."
        }
    }
}
