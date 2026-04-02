@preconcurrency import ARKit
import simd
import SwiftUI

extension CameraView {
    func handleMeasureTap(at point: CGPoint) {
        guard arSessionManager.hasLiDAR, isMeasureMode else { return }

        if lidarStartPoint != nil, lidarEndPoint != nil {
            lidarStartPoint = nil
            lidarEndPoint = nil
            lidarDistance = nil
            lidarStartWorldPos = nil
            return
        }

        guard let worldPos = performRaycast(screenPoint: point) else { return }

        if lidarStartPoint == nil {
            lidarStartPoint = point
            lidarStartWorldPos = worldPos
        } else {
            lidarEndPoint = point
            if let startPos = lidarStartWorldPos {
                lidarDistance = simd_distance(startPos, worldPos)
            }
        }
    }

    private func performRaycast(screenPoint _: CGPoint) -> SIMD3<Float>? {
        guard arSessionManager.isSessionRunning else { return nil }
        let camera = arSessionManager.cameraTransform
        let forward = -SIMD3<Float>(camera.columns.2.x, camera.columns.2.y, camera.columns.2.z)
        let origin = SIMD3<Float>(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        let query = ARRaycastQuery(
            origin: origin,
            direction: forward,
            allowing: .estimatedPlane,
            alignment: .any
        )
        let results = arSessionManager.raycast(query)
        guard let first = results.first else { return nil }
        return SIMD3<Float>(
            first.worldTransform.columns.3.x,
            first.worldTransform.columns.3.y,
            first.worldTransform.columns.3.z
        )
    }
}
