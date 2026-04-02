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
    private(set) var cameraEulerAngles: simd_float3 = .zero
    private(set) var hasLiDAR: Bool = false
    private(set) var isARSupported: Bool = false

    private(set) var savedTransform: simd_float4x4?

    var positionThreshold: Float {
        hasLiDAR ? 0.05 : 0.15
    }

    private let orientationThreshold: Float = 0.035

    var positionDelta: SIMD3<Float> {
        guard let saved = savedTransform else { return .zero }
        let cur = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let sav = SIMD3<Float>(saved.columns.3.x, saved.columns.3.y, saved.columns.3.z)
        return cur - sav
    }

    var orientationDelta: simd_float3 {
        guard let saved = savedTransform else { return .zero }
        let savedEuler = eulerAngles(from: saved)
        return cameraEulerAngles - savedEuler
    }

    var isPositionMatched: Bool {
        guard savedTransform != nil else { return false }
        return simd_length(positionDelta) <= positionThreshold
    }

    var isOrientationMatched: Bool {
        guard savedTransform != nil else { return false }
        let delta = orientationDelta
        return abs(delta.x) <= orientationThreshold
            && abs(delta.y) <= orientationThreshold
            && abs(delta.z) <= orientationThreshold
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

        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
    }

    func stopSession() {
        session.pause()
        isSessionRunning = false
        savedTransform = nil
    }

    func saveCurrentTransform() {
        savedTransform = cameraTransform
    }

    /// Backward compat shim used by CameraView+AR
    func setSavedAnchorTransform(_ transform: simd_float4x4) {
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
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
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

    private func eulerAngles(from transform: simd_float4x4) -> simd_float3 {
        let pitch = asin(-transform.columns.2.y)
        let yaw = atan2(transform.columns.2.x, transform.columns.2.z)
        let roll = atan2(transform.columns.1.x, transform.columns.0.x)
        return simd_float3(pitch, yaw, roll)
    }
}

extension ARSessionManager: ARSessionDelegate {
    nonisolated func session(_: ARSession, didUpdate frame: ARFrame) {
        let status = frame.worldMappingStatus
        let tracking = frame.camera.trackingState
        let transform = frame.camera.transform
        let euler = frame.camera.eulerAngles
        Task { @MainActor [weak self] in
            guard let self else { return }
            worldMappingStatus = status
            trackingState = tracking
            cameraTransform = transform
            cameraEulerAngles = euler
        }
    }

    nonisolated func session(_: ARSession, didFailWithError _: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            isSessionRunning = false
        }
    }
}
