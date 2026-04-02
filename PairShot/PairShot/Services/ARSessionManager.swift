@preconcurrency import ARKit
import Foundation
import Observation
import simd

enum ARSessionError: Error {
    case sessionNotRunning
    case worldMapUnavailable
}

@Observable
@MainActor
final class ARSessionManager: NSObject {
    private(set) var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    private(set) var trackingState: ARCamera.TrackingState = .notAvailable
    private(set) var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    private(set) var isSessionRunning: Bool = false
    private(set) var hasLiDAR: Bool = false
    private(set) var isARSupported: Bool = false
    private(set) var positionDelta: SIMD3<Float> = .zero
    private(set) var isPositionMatched: Bool = false

    var positionThreshold: Float {
        hasLiDAR ? 0.10 : 0.20
    }

    @ObservationIgnored
    private nonisolated(unsafe) let session = ARSession()

    @ObservationIgnored
    private var savedAnchorTransform: simd_float4x4?

    override init() {
        super.init()
        isARSupported = ARWorldTrackingConfiguration.isSupported
        hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        session.delegate = self
    }

    func startSession(withWorldMap worldMap: ARWorldMap? = nil) {
        guard isARSupported else { return }
        let config = ARWorldTrackingConfiguration()
        if hasLiDAR {
            config.sceneReconstruction = .mesh
        }
        if let worldMap {
            config.initialWorldMap = worldMap
        }
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
    }

    func stopSession() {
        session.pause()
        isSessionRunning = false
        savedAnchorTransform = nil
        positionDelta = .zero
        isPositionMatched = false
    }

    func captureWorldMap() async throws -> ARWorldMap {
        guard isSessionRunning else { throw ARSessionError.sessionNotRunning }
        return try await withCheckedThrowingContinuation { continuation in
            session.getCurrentWorldMap { worldMap, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let worldMap {
                    continuation.resume(returning: worldMap)
                } else {
                    continuation.resume(throwing: ARSessionError.worldMapUnavailable)
                }
            }
        }
    }

    func raycast(_ query: ARRaycastQuery) -> [ARRaycastResult] {
        session.raycast(query)
    }

    func saveWorldMap(_ worldMap: ARWorldMap, to url: URL) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try data.write(to: url)
    }

    func loadWorldMap(from url: URL) throws -> ARWorldMap {
        let data = try Data(contentsOf: url)
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw ARSessionError.worldMapUnavailable
        }
        return worldMap
    }

    func setSavedAnchorTransform(_ transform: simd_float4x4) {
        savedAnchorTransform = transform
        updatePositionDelta(currentTransform: cameraTransform)
    }

    private func updatePositionDelta(currentTransform: simd_float4x4) {
        guard let saved = savedAnchorTransform else {
            positionDelta = .zero
            isPositionMatched = false
            return
        }
        let currentPos = SIMD3<Float>(
            currentTransform.columns.3.x,
            currentTransform.columns.3.y,
            currentTransform.columns.3.z
        )
        let savedPos = SIMD3<Float>(
            saved.columns.3.x,
            saved.columns.3.y,
            saved.columns.3.z
        )
        positionDelta = currentPos - savedPos
        isPositionMatched = simd_length(positionDelta) <= positionThreshold
    }
}

extension ARSessionManager: ARSessionDelegate {
    nonisolated func session(_: ARSession, didUpdate frame: ARFrame) {
        let status = frame.worldMappingStatus
        let tracking = frame.camera.trackingState
        let transform = frame.camera.transform
        Task { @MainActor [weak self] in
            guard let self else { return }
            worldMappingStatus = status
            trackingState = tracking
            cameraTransform = transform
            updatePositionDelta(currentTransform: transform)
        }
    }

    nonisolated func session(_: ARSession, didFailWithError _: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            isSessionRunning = false
        }
    }
}
