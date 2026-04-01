---
paths:
  - "PairShot/PairShot/Views/Camera/**"
  - "PairShot/PairShot/Views/Archive/**"
  - "PairShot/PairShot/Views/Gallery/**"
---

# 카메라 화면 표시 규칙

카메라 촬영 화면(CameraView)은 반드시 `fullScreenCover`로 표시한다. NavigationStack push나 sheet는 사용하지 않는다.

근거:
- UIImagePickerController 카메라 모드는 UIModalPresentationFullScreen 필수 (Apple 공식)
- push 방식은 interactivePopGestureRecognizer가 카메라 제스처(핀치 줌, 포커스 드래그)와 충돌
- sheet는 swipe-to-dismiss로 촬영 중 실수 종료 가능
- fullScreenCover는 swipe-dismiss 없음 + 전체화면 프리뷰 보장

패턴:
```swift
@State private var cameraDestination: CameraDestination?

.fullScreenCover(item: $cameraDestination) { destination in
    switch destination {
    case .beforeCamera(let project):
        CameraView(project: project)
    case .afterCamera(let project, let pair):
        CameraView(project: project, existingPair: pair)
    }
}
```

뒤로가기는 CameraView 내부의 커스텀 오버레이 버튼 + @Environment(\.dismiss)로 처리한다.
