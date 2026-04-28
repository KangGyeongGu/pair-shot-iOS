@preconcurrency import AVFoundation
import CoreLocation
import Foundation
import Observation
import Photos

@MainActor
@Observable
final class PermissionStatusService: NSObject {
    private static let initialBundleRequestedKey = "pairshot.permissions.requestedInitialBundle"

    private(set) var cameraStatus: AVAuthorizationStatus
    private(set) var photoLibraryStatus: PHAuthorizationStatus
    private(set) var locationStatus: CLAuthorizationStatus

    private let defaults: UserDefaults
    private let locationManager: CLLocationManager
    private var locationContinuation: CheckedContinuation<Void, Never>?

    var hasRequestedInitialPermissions: Bool {
        defaults.bool(forKey: Self.initialBundleRequestedKey)
    }

    var isBlocked: Bool {
        Self.isBlockingStatus(cameraStatus) || Self.isBlockingPhotoStatus(photoLibraryStatus)
    }

    var isCameraBlocked: Bool {
        Self.isBlockingStatus(cameraStatus)
    }

    var isPhotoLibraryBlocked: Bool {
        Self.isBlockingPhotoStatus(photoLibraryStatus)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        locationManager = CLLocationManager()
        locationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    private static func isBlockingStatus(_ status: AVAuthorizationStatus) -> Bool {
        status == .denied || status == .restricted
    }

    private static func isBlockingPhotoStatus(_ status: PHAuthorizationStatus) -> Bool {
        status == .denied || status == .restricted
    }

    func refreshAll() async {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        locationStatus = locationManager.authorizationStatus
    }

    @discardableResult
    func requestCameraAccessIfNeeded() async -> Bool {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        switch current {
            case .authorized:
                cameraStatus = current
                return true

            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                return granted

            case .denied, .restricted:
                cameraStatus = current
                return false

            @unknown default:
                cameraStatus = current
                return false
        }
    }

    func requestAllInOrder() async {
        await requestCameraIfNeeded()
        await requestPhotoLibraryIfNeeded()
        await requestLocationIfNeeded()
        defaults.set(true, forKey: Self.initialBundleRequestedKey)
    }

    private func requestCameraIfNeeded() async {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        if current == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func requestPhotoLibraryIfNeeded() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func requestLocationIfNeeded() async {
        let current = locationManager.authorizationStatus
        guard current == .notDetermined else {
            locationStatus = current
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.locationContinuation = continuation
            self.locationManager.requestWhenInUseAuthorization()
        }
        locationStatus = locationManager.authorizationStatus
    }
}

extension PermissionStatusService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            locationStatus = status
            if status != .notDetermined, let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume()
            }
        }
    }
}
