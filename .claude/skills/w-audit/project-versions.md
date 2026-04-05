# Project Version Snapshot

의미론적 리뷰 에이전트가 참조할 수 있는 문서 범위를 제한하는 버전 기준.
모든 code-reviewer 에이전트는 이 파일에 명시된 버전과 **정확히 일치**하는 Apple 공식 문서/WWDC 세션만 인용해야 함.

## 빌드 환경

| 항목 | 값 |
|---|---|
| Xcode | 26.4 (Build 17E192) |
| Swift 컴파일러 | 6.3 (swiftlang-6.3.0.123.5) |
| `SWIFT_VERSION` (language mode) | 5.0 |
| `SWIFT_STRICT_CONCURRENCY` | complete (P5 audit 시 적용) |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | YES |
| `IPHONEOS_DEPLOYMENT_TARGET` | 26.4 |
| iOS Simulator SDK | 26.4 |
| macOS (호스트) | 26.3.1 |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor (전역 기본 격리) |

## 프레임워크 사용

프로젝트에서 실제 사용 중인 프레임워크만. 버전은 deployment target 기준 (iOS 26.4).

| 프레임워크 | 용도 | 주의할 API 변경점 |
|---|---|---|
| SwiftUI | UI 전체 | iOS 17+ Observation, iOS 18+ Entry, iOS 26 최신 |
| SwiftData | 로컬 DB | iOS 17 도입, iOS 18 history tracking, iOS 26 최신 |
| AVFoundation | 카메라 (48MP, macro, low-light) | iOS 18+ systemRecommendedVideoZoomRange/ExposureBiasRange/displayVideoZoomFactorMultiplier, iOS 26+ constituentDevices+nominalFocalLengthIn35mmFilm |
| ARKit | 정밀 재위치 (LiDAR 옵션) | iOS 17+ |
| CoreMotion | 자이로/나침반 | iOS 17+ |
| CoreLocation | GPS | iOS 17+ |
| Vision | AI 정렬/유사도 | iOS 17+ (VNHomographicImageRegistrationRequest iOS 11+, Revision2 iOS 17+), iOS 14+ VNTrackHomographicImageRegistrationRequest |
| CoreImage | 필터 체인 | iOS 13+ CIFilterBuiltins, iOS 14+ CIColorAbsoluteDifference, CIContext NS_SWIFT_SENDABLE |
| CoreHaptics | 햅틱 | iOS 13+ |
| PDFKit | 보고서 | iOS 17+ |
| ZIPFoundation | 압축 | 외부 패키지 (버전은 Package.resolved 확인) |

## 참조 가능 문서

### ✅ 허용 (iOS 26.4 deployment target이므로)
- iOS 17~26 API를 다루는 Apple Developer Documentation
- WWDC 2023~2025 세션 (iOS 17~26 대응)
- `.claude/apple-sdk-refs/` 내 헤더 파일 (프로젝트에 동봉된 SDK 참조)
- Core Image / Vision / SwiftData / SwiftUI WWDC 세션 중 **해당 iOS 버전과 일치**하는 것

### ⛔ 금지
- iOS 16 이하 전용 API 가이드 (deployment target 위반)
- 비공식 블로그/Stack Overflow (인용 근거 부족)
- 추측에 기반한 "일반적으로 알려진 best practice"
- 다른 플랫폼(macOS/watchOS/tvOS) 전용 문서

## 성능 리뷰 우선 참조 (성능 병목 검증 시)

Agent는 다음 레퍼런스를 WebFetch로 직접 확인하고 인용:

1. **SwiftUI 성능**
   - "Demystify SwiftUI performance" (WWDC23, iOS 17 기준이지만 26에서도 유효)
   - "Writing performant SwiftUI" (WWDC22~25 중 최신)
   - "Improving app responsiveness" (Apple Developer Documentation)
   - View 재평가/Identity/Lifetime 관련 공식 가이드

2. **SwiftData 성능**
   - "What's new in SwiftData" (WWDC24/25)
   - FetchDescriptor fetchLimit/relationship loading 가이드
   - iOS 26 compiled predicate 최적화 (iOS 18+)

3. **Core Image 성능**
   - `CIContext` Discussion 헤더 주석 (캐시/중간 버퍼)
   - "Processing an image using built-in filters" Apple doc
   - GPU 렌더 vs software renderer 가이드

4. **Vision 성능**
   - `VNRequest.usesCPUOnly` / `.ciContext` 옵션 문서
   - Revision2 성능 차이 (WWDC23)

5. **AVFoundation 카메라 성능**
   - `AVCaptureSession` 세션 설정 비용
   - Photo pipeline latency 가이드

6. **일반 iOS 앱 응답성**
   - Apple "Improving app responsiveness" (최신)
   - Instruments Time Profiler / Animation Hitches 해석 가이드

## 리뷰 에이전트 프롬프트 템플릿 (필수 삽입)

```
## 버전 제약 (반드시 준수)
이 프로젝트는 **iOS 26.4 deployment target, Swift 5 모드 + Strict Concurrency complete**를 사용한다.
- 리뷰 시 주장하는 finding은 반드시 (1) Apple 공식 문서 URL 또는 (2) `.claude/apple-sdk-refs/` 헤더 파일의 경로:줄번호 로 인용되어야 한다.
- 인용 없는 주장, "일반적으로 알려진" 식의 추측은 finding에 포함 금지.
- iOS 16 이하 전용 API 언급 금지. 해당 API가 iOS 17+ 에서 교체되었다면 교체 API만 참조.
- WWDC 세션 인용 시 연도와 세션 제목 명시.
- 의심스러운 성능 주장은 "WebFetch로 해당 문서를 읽고 인용"하거나 finding에서 제외.
```
