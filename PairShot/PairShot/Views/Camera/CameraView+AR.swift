import ARKit
import SwiftUI

extension CameraView {
    func withARObservation() -> some View {
        onChange(of: arSessionManager.worldMappingStatus) { _, status in
            if status == .mapped, !isARRelocalized {
                isARRelocalized = true
            }
        }
        .onChange(of: arSessionManager.isPositionMatched) { _, matched in
            if matched {
                hapticService.triggerSuccess()
            }
        }
    }

    func loadWorldMapIfNeeded() async {
        // worldMap 존재 여부만 확인 — ARSession은 시작하지 않음 (AVCaptureSession과 충돌)
        // ARKit 재위치는 향후 별도 모드 전환으로 구현 예정
    }

    func captureAndSaveWorldMap(for photo: Photo, pairId: UUID) async {
        arSessionManager.startSession()
        for _ in 0 ..< 50 {
            try? await Task.sleep(for: .milliseconds(100))
            if arSessionManager.worldMappingStatus == .mapped ||
                arSessionManager.worldMappingStatus == .extending { break }
        }
        do {
            let worldMap = try await arSessionManager.captureWorldMap()
            arSessionManager.setSavedAnchorTransform(arSessionManager.cameraTransform)
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let wmPath = "projects/\(project.id)/pairs/\(pairId)/worldmap.arworldmap"
            let wmURL = docsURL.appendingPathComponent(wmPath)
            try FileManager.default.createDirectory(
                at: wmURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try arSessionManager.saveWorldMap(worldMap, to: wmURL)
            photo.worldMapPath = wmPath
        } catch {
            // worldMap 저장 실패는 무시 — 센서 가이드 fallback으로 동작
        }
        arSessionManager.stopSession()
    }
}
