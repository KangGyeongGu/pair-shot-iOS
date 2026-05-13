# 데이터 모델

SwiftData (영속화) + UserDefaults (설정) + Keychain (디바이스 UUID 1건) + PhotoKit (사진 본체).

---

## SwiftData

### Schema

`SchemaV1` (`Data/Models/Schemas/SchemaV1.swift`) — `versionIdentifier (1, 0, 0)`, 모델 `[AlbumEntity, PhotoPairEntity, ExportHistoryEntity]`.

`PairShotMigrationPlan` (`Data/Models/Schemas/PairShotMigrationPlan.swift`) — `schemas: [SchemaV1.self]`, `stages: []` (현재 V1 단일, 마이그레이션 미정의).

### `PhotoPairEntity`

| 필드 | 타입 | 비고 |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `beforePhotoLocalIdentifier` | `String?` | PHAsset `localIdentifier` |
| `afterPhotoLocalIdentifier` | `String?` | PHAsset `localIdentifier` |
| `beforeZoomFactor` | `Double` | After 촬영 시 줌 복원에 사용 |
| `beforeLensIdentifier` | `String` | `"back"` / `"front"` |
| `createdAt` | `Date` | |
| `updatedAt` | `Date` | |
| `afterCapturedAt` | `Date?` | |
| `latitude` / `longitude` | `Double?` | Before 촬영 시점 캐시 |
| `locationLabel` | `String?` | reverse geocode 결과 |
| `cameraSettingsData` | `Data?` | `@Attribute(.externalStorage)`, JSON-encoded `CameraSettings` |
| `albums` | `[AlbumEntity]` | many-to-many |
| `exportHistory` | `[ExportHistoryEntity]` | `@Relationship(deleteRule: .cascade, inverse: \.pair)` |

### `AlbumEntity`

| 필드 | 타입 |
|---|---|
| `id` | `UUID` |
| `name` | `String` |
| `createdAt` / `updatedAt` | `Date` |
| `latitude` / `longitude` | `Double?` |
| `locationLabel` | `String?` |
| `pairs` | `[PhotoPairEntity]` (`deleteRule: .nullify, inverse: \PhotoPairEntity.albums`) |

### `ExportHistoryEntity`

| 필드 | 타입 | 비고 |
|---|---|---|
| `id` | `UUID` | |
| `kindRaw` | `String` | `combined` / `watermarkedBefore` / `watermarkedAfter` |
| `photoLocalIdentifier` | `String` | PHAsset |
| `createdAt` | `Date` | |
| `pair` | `PhotoPairEntity?` | inverse |

### Domain mirror

- `PhotoPair` (`Domain/Models/PhotoPair.swift`) — entity 미러 + `albumIds`, `firstAlbumName`, `hasCombinedExport` (= `exportHistory.contains { $0.kind == .combined }`)
- `Album` (`Domain/Models/Album.swift`) — entity 미러 + `pairIds`
- `PairStatus` (`Domain/Models/PairStatus.swift`)
  - `.scheduled` — before 만 존재
  - `.afterOnly` — after 만 존재 (드문 케이스)
  - `.captured` — 둘 다 존재

### ModelContainer

`App/PairShotApp.swift` 의 `ModelContainerBootstrap.bootstrap()` 에서 생성. Application Support 디렉토리 사용. 생성 실패 시 `isStoredInMemoryOnly: true` fallback + `fallbackActive=true` 상태로 UI alert 노출.

`SwiftDataPhotoPairRepository` / `SwiftDataAlbumRepository` 둘 다 `@MainActor`, `container.mainContext` 사용.

---

## 사진 본체

**모든 사진 (Before / After / Combined / Watermarked) 은 디바이스 시스템 사진 라이브러리에 PHAsset 으로 저장.** 앱 내 디스크에 사진 파일을 두지 않음.

`PhotoLibraryService.saveImage` (`Data/Storage/PhotoLibraryService.swift`):
- `PHAssetCreationRequest.forAsset().addResource(with: .photo, data:, options:)`
- Deferred proxy 인 경우 `.photoProxy` 타입 사용
- `uniformTypeIdentifier = "public.jpeg"` (HEIF 미사용)
- 반환된 `localIdentifier` 문자열만 SwiftData 에 저장

### Thumbnail

디스크 캐시 없음. 메모리 캐시만:
- `PhotoLibraryThumbnailCache` — `NSCache<NSString, UIImage>`
- 기본 256 entry / 64 MB
- `PHCachingImageManager` 사용
- 기본 픽셀 크기 600

---

## Export 임시 파일

| 종류 | 경로 | 형식 | 정리 시점 |
|---|---|---|---|
| ZIP staging | `tempDirectory/pairshot-zip-<UUID>/` | 폴더 | export 완료 후 |
| ZIP 최종 | `tempDirectory/PairShot_<yyyyMMdd_HHmmss>.zip` | 파일 | DocumentPicker 또는 ActivityVC 종료 후 |
| Share temp | `tempDirectory/pairshot-share/<sanitized-name>` | 파일 | ActivityVC 종료 후 |

`FileManager.default.temporaryDirectory` 만 사용. Documents 폴더 미사용.

---

## UserDefaults 설정

모든 키 prefix `pairshot.*` (`Data/Storage/AppSettingsKeys.swift`).

### 주요 키

| 키 | 타입 | 비고 |
|---|---|---|
| `pairshot.language` | `String` | `system` / `ko` / `en` |
| `pairshot.theme` | `String` | `system` / `light` / `dark` |
| `pairshot.jpegQuality` | `CaptureQualityPreset` | |
| `pairshot.ghostOverlayOpacity` | `Double` | 0.0 ~ 1.0 |
| `pairshot.filenamePrefix` | `String` | sanitize 후 저장 |
| `pairshot.watermarkSettings` | `String` (JSON) | `WatermarkSettings` 직렬화 |
| `pairshot.combineSettings` | `String` (JSON) | `CombineSettings` 직렬화 |
| `pairshot.embedGPSInPhoto` | `Bool` | 합성·export EXIF GPS 포함 여부 |
| `pairshot.exportIncludeCombined/Before/After` | `Bool` | Export 기본값 |
| `pairshot.exportFormat` | `String` | `individualImages` / `zip` |
| `pairshot.exportApplyWatermark/Combine` | `Bool` | Export 기본값 |
| `pairshot.adFreeStore.snapshot` | `String` (JSON) | AdFree 상태 캐시 |
| `pairshot.permissions.requestedInitialBundle` | `Bool` | 첫 일괄 권한 요청 완료 표식 |

### 영속화 진입점
- `AppSettings` (`Domain/Models/AppSettings.swift`) — `@Observable` wrapper, computed property 가 `UserDefaults.standard` 에 직접 set/get
- `UserDefaultsAppSettingsRepository` — snapshot 기반 protocol impl (`nonisolated`, `@unchecked Sendable`)
- WatermarkSettings / CombineSettings 는 JSON-encoded string 으로 저장 후 `@ObservationIgnored` 캐시로 디코딩 결과 재사용

---

## Keychain

`KeychainDeviceUUID` 1건만 사용 (`Data/Coupon/KeychainDeviceUUID.swift`).

- service: `com.pairshot.deviceUUID`
- account: `primary`
- 값: `UUID().uuidString`
- accessible: `kSecAttrAccessibleAfterFirstUnlock`
- synchronizable: `false`

`DeviceHashProvider.deviceHash()` = `SHA256(UUID utf8).hex` — 쿠폰 API 요청 시 `d` 쿼리 파라미터로 전송. UUID 자체는 네트워크로 나가지 않음.

---

## Repository protocols

| Protocol (Domain) | 구현 (Data) | 비고 |
|---|---|---|
| `PhotoPairRepository` | `SwiftDataPhotoPairRepository` | `@MainActor` |
| `AlbumRepository` | `SwiftDataAlbumRepository` | `@MainActor` |
| `AppSettingsRepository` | `UserDefaultsAppSettingsRepository` | `nonisolated`, snapshot |
