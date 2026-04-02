@preconcurrency import ARKit
import AVFoundation
import CoreImage
import Foundation
import Observation
import simd
import UIKit

enum ARSessionError: Error {
    case sessionNotRunning
    case worldMapUnavailable
    case captureHighResFailed
    case pixelBufferConversionFailed
}

@Observable
@MainActor
final class ARSessionManager: NSObject {
    let session = ARSession()

    private(set) var isSessionRunning: Bool = false
    private(set) var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    private(set) var trackingState: ARCamera.TrackingState = .notAvailable
    private(set) var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    private(set) var hasLiDAR: Bool = false
    private(set) var isARSupported: Bool = false

    private(set) var savedTransform: simd_float4x4?

    var positionThreshold: Float {
        hasLiDAR ? 0.05 : 0.15
    }

    let orientationThreshold: Float = 0.035

    var positionDelta: SIMD3<Float> {
        guard let saved = savedTransform else { return .zero }
        let cur = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let sav = SIMD3<Float>(saved.columns.3.x, saved.columns.3.y, saved.columns.3.z)
        let worldDelta = cur - sav
        // 좌우/앞뒤: 카메라 로컬 수평면 기준
        let fwd = Self.forwardVector(from: saved)
        let flatFwd = normalize(SIMD3<Float>(fwd.x, 0, fwd.z))
        let flatRight = SIMD3<Float>(flatFwd.z, 0, -flatFwd.x)
        let localX = simd_dot(worldDelta, flatRight)
        let localZ = simd_dot(worldDelta, flatFwd)
        // 위아래: world Y (중력 기준)
        let localY = worldDelta.y
        return SIMD3<Float>(localX, localY, localZ)
    }

    private static func forwardVector(from transform: simd_float4x4) -> SIMD3<Float> {
        -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
    }

    private static func upVector(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
    }

    var yawDelta: Float {
        guard let saved = savedTransform else { return 0 }
        let curFwd = Self.forwardVector(from: cameraTransform)
        let savFwd = Self.forwardVector(from: saved)
        let curFlat = normalize(SIMD2<Float>(curFwd.x, curFwd.z))
        let savFlat = normalize(SIMD2<Float>(savFwd.x, savFwd.z))
        let cross = curFlat.x * savFlat.y - curFlat.y * savFlat.x
        let dot = simd_dot(curFlat, savFlat)
        return atan2(cross, dot)
    }

    var pitchDelta: Float {
        guard let saved = savedTransform else { return 0 }
        let curFwd = Self.forwardVector(from: cameraTransform)
        let savFwd = Self.forwardVector(from: saved)
        let curPitch = asin(max(-1, min(1, curFwd.y)))
        let savPitch = asin(max(-1, min(1, savFwd.y)))
        return curPitch - savPitch
    }

    var rollDelta: Float {
        guard let saved = savedTransform else { return 0 }
        let curUp = Self.upVector(from: cameraTransform)
        let savUp = Self.upVector(from: saved)
        let curRoll = atan2(curUp.x, curUp.y)
        let savRoll = atan2(savUp.x, savUp.y)
        var delta = curRoll - savRoll
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }

    var isPositionMatched: Bool {
        guard savedTransform != nil else { return false }
        return simd_length(positionDelta) <= positionThreshold
    }

    var isOrientationMatched: Bool {
        guard savedTransform != nil else { return false }
        return abs(yawDelta) <= orientationThreshold
            && abs(pitchDelta) <= orientationThreshold
            && abs(rollDelta) <= orientationThreshold
    }

    var isFullyAligned: Bool {
        isPositionMatched && isOrientationMatched
    }

    var captureDevice: AVCaptureDevice? {
        ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera
    }

    override init() {
        super.init()
        isARSupported = ARWorldTrackingConfiguration.isSupported
        hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        session.delegate = self
    }

    func startSession(withWorldMap worldMap: ARWorldMap? = nil) {
        guard isARSupported else { return }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading

        if let hiResFormat = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing {
            config.videoFormat = hiResFormat
        }

        if hasLiDAR {
            config.sceneReconstruction = .mesh
        }

        if let worldMap {
            config.initialWorldMap = worldMap
        }

        if worldMap != nil {
            session.run(config)
        } else {
            session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }
        isSessionRunning = true
    }

    func stopSession() {
        session.pause()
        isSessionRunning = false
    }

    func clearSavedPose() {
        savedTransform = nil
    }

    func saveCurrentPose() {
        savedTransform = cameraTransform
    }

    func setSavedPose(transform: simd_float4x4) {
        savedTransform = transform
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

    func capturePhoto() async throws -> (UIImage, simd_float4x4) {
        guard isSessionRunning else { throw ARSessionError.sessionNotRunning }
        let frame: ARFrame = try await withCheckedThrowingContinuation { continuation in
            session.captureHighResolutionFrame { frame, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let frame {
                    continuation.resume(returning: frame)
                } else {
                    continuation.resume(throwing: ARSessionError.captureHighResFailed)
                }
            }
        }

        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw ARSessionError.pixelBufferConversionFailed
        }
        let image = UIImage(cgImage: cgImage)
        return (image, frame.camera.transform)
    }

    func raycast(_ query: ARRaycastQuery) -> [ARRaycastResult] {
        session.raycast(query)
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
        }
    }

    nonisolated func session(_: ARSession, didFailWithError _: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            isSessionRunning = false
        }
    }
}
