import AVFoundation
import CoreVideo
import SwiftData
import SwiftUI
import UIKit

private nonisolated struct SendablePixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

@MainActor
final class VideoFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrame: ((CVPixelBuffer) -> Void)?

    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let wrapped = SendablePixelBuffer(buffer: pixelBuffer)
        Task { @MainActor [weak self] in
            self?.onFrame?(wrapped.buffer)
        }
    }
}

struct PairCameraView: View {
    let project: Project
    var existingPair: PhotoPair?
    let sensorManager: SensorManager

    var isBefore: Bool {
        existingPair == nil
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State var cameraManager = CameraManager()
    @State var cameraSettings = CameraSettings()
    @State var depthService = DepthCaptureService()
    @State var positionMatcher = PositionMatchingService()
    @State var hapticService = HapticService()
    @State var lowLightManager = LowLightManager()

    @State var beforeImage: UIImage?
    @State var ghostOpacity: Double = 0.0
    @State var ghostAutoActivated: Bool = false
    @State var ghostDefaultOpacity: Double = 0.15

    @State var captureCount: Int = 0
    @State var timerCountdown: Int = 0
    @State var isTimerRunning: Bool = false
    @State var isMenuExpanded: Bool = false
    @State var pinchBaseZoom: CGFloat = 1.0
    @State var focusPoint: CGPoint?
    @State var showFocusIndicator = false
    @State var focusIndicatorScale: CGFloat = 1.0
    @State var focusIndicatorOpacity: CGFloat = 1.0
    @State var focusHideTask: Task<Void, Never>?
    @State var exposureBias: Float = 0
    @State var isDraggingExposure = false
    @State var exposureDragStartY: CGFloat = 0
    @State var exposureBiasAtDragStart: Float = 0
    @State var wasAligned = false

    @State var beforePitch: Double = 0
    @State var beforeRoll: Double = 0
    @State var beforeHeading: Double = 0
    @State var beforeDepth: Double = 0

    @State private var videoDelegate = VideoFrameDelegate()
    @State private var videoOutput = AVCaptureVideoDataOutput()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                cameraPreviewSection
                VStack(spacing: 0) {
                    if lowLightManager.isTorchActive {
                        torchIndicator.padding(.top, 4)
                    }
                    ShutterButton { handleShutterTap() }
                        .padding(.vertical, 12)
                }
                .background(Color.black)
                HStack {
                    thumbnailView
                    Spacer()
                    captureCountLabel
                    Spacer()
                    cameraSwitchButton
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.black)
            }
        }
        .statusBarHidden(true)
        .gesture(menuSwipeGesture)
        .overlay {
            if isMenuExpanded {
                menuPanel.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if isTimerRunning, timerCountdown > 0 { timerCountdownOverlay }
        }
        .task { await loadCameraAndSetup() }
        .task {
            if !isBefore {
                let refPath = existingPair?.beforePhoto?.referenceImagePath
                print("[PAIR-CAM] refPath=\(refPath ?? "nil")")
                if let refPath {
                    let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let url = docsURL.appendingPathComponent(refPath)
                    let exists = FileManager.default.fileExists(atPath: url.path)
                    print("[PAIR-CAM] refImage exists=\(exists), path=\(url.path)")
                    if let cgImage = UIImage(contentsOfFile: url.path)?.cgImage {
                        positionMatcher.setReferenceImage(cgImage)
                        print("[PAIR-CAM] setReferenceImage OK, isActive=\(positionMatcher.isActive)")
                    } else {
                        print("[PAIR-CAM] Failed to load reference image")
                    }
                }
            }
        }
        .onAppear { onViewAppear() }
        .onDisappear { onViewDisappear() }
        .onChange(of: sensorManager.currentPitch) { _, _ in handleSensorUpdate() }
        .onChange(of: sensorManager.currentHeading) { _, _ in handleSensorUpdate() }
        .onChange(of: cameraManager.saveResult) { _, result in
            if let result { handleSaveResult(result) }
        }
        .onChange(of: cameraManager.isSessionRunning) { _, running in
            if running { applyZoomInfo() }
        }
        .onChange(of: cameraManager.capturedPhoto) { _, newPhoto in
            if newPhoto != nil { captureCount += 1 }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AVCaptureDevice.subjectAreaDidChangeNotification)
        ) { _ in
            cameraManager.resetFocusAndExposure()
            showFocusIndicator = false
        }
    }
}

extension PairCameraView {
    func loadCameraAndSetup() async {
        let granted = await cameraManager.requestAuthorization()
        guard granted else { return }
        cameraManager.startSession()

        if !isBefore, let filePath = existingPair?.beforePhoto?.filePath {
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fullURL = docsURL.appendingPathComponent(filePath)
            if let image = UIImage(contentsOfFile: fullURL.path) {
                beforeImage = image.downscaledTo1080p()
                ghostOpacity = 0.35
            }
        }

        if !isBefore, let beforePhoto = existingPair?.beforePhoto {
            beforePitch = beforePhoto.pitch ?? 0
            beforeRoll = beforePhoto.roll ?? 0
            beforeHeading = beforePhoto.heading ?? 0
            beforeDepth = beforePhoto.depthAtCenter ?? 0
        }
    }

    func onViewAppear() {
        if depthService.isLiDARAvailable {
            depthService.configure(
                session: cameraManager.captureSession,
                queue: cameraManager.captureSessionQueue
            )
        }
        if !isBefore, depthService.isLiDARAvailable {
            print("[PAIR-CAM] Setting up video frame delegate for Vision matching")
            let matcher = positionMatcher
            let depth = depthService
            var frameCount = 0
            videoDelegate.onFrame = { buffer in
                frameCount += 1
                if frameCount % 30 == 1 {
                    print(
                        "[PAIR-CAM] frame #\(frameCount), depth=\(depth.centerDepth), fx=\(depth.focalLengthPixels ?? 0), matcher.isActive=\(matcher.isActive)"
                    )
                    print(
                        "[PAIR-CAM] lateral=\(matcher.lateralDisplacementCm), vertical=\(matcher.verticalDisplacementCm)"
                    )
                }
                matcher.processFrame(
                    buffer,
                    depth: depth.centerDepth,
                    focalLengthPx: depth.focalLengthPixels ?? 2800
                )
            }
            let queue = DispatchQueue(label: "com.pairshot.videoframes")
            videoOutput.setSampleBufferDelegate(videoDelegate, queue: queue)
            cameraManager.addVideoDataOutput(videoOutput, on: cameraManager.captureSessionQueue)
        } else {
            print(
                "[PAIR-CAM] Video delegate NOT set up: isBefore=\(isBefore), hasLiDAR=\(depthService.isLiDARAvailable)"
            )
        }
    }

    func onViewDisappear() {
        depthService.stopStreaming()
        positionMatcher.stop()
        cameraManager.removeOutput(videoOutput, on: cameraManager.captureSessionQueue)
        cameraManager.stopSession()
    }

    func handleShutterTap() {
        if cameraSettings.timerDuration == .off {
            fireCapture()
        } else {
            startTimerCapture()
        }
    }

    func fireCapture() {
        if isBefore {
            let pair = PhotoPair(project: project)
            modelContext.insert(pair)
            project.pairs.append(pair)
            cameraManager.capturePhoto(projectId: project.id, pairId: pair.id, isBefore: true)
        } else if let pair = existingPair {
            cameraManager.capturePhoto(projectId: project.id, pairId: pair.id, isBefore: false)
        }
    }

    func startTimerCapture() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        timerCountdown = cameraSettings.timerDuration.seconds
        Task {
            while timerCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                withAnimation { timerCountdown -= 1 }
            }
            fireCapture()
            isTimerRunning = false
        }
    }

    func applyZoomInfo() {
        let info = cameraManager.getZoomInfo()
        cameraSettings.allFixedFactors = info.allFixedFactors
        cameraSettings.focalLengthMap = info.focalLengthMap
        let mult = info.displayMultiplier
        if mult > 0 {
            cameraSettings.availableZoomFactors = [0.5, 1.0, 2.0, 3.0].map { $0 / mult }
        } else {
            cameraSettings.availableZoomFactors = info.allFixedFactors
        }
        cameraSettings.currentZoomFactor = info.defaultFactor
        cameraSettings.zoomDivisor = info.displayMultiplier
        cameraSettings.minZoomFactor = info.minFactor
        cameraSettings.maxZoomFactor = info.recommendedMaxFactor
    }

    func handleSensorUpdate() {
        guard !isBefore else { return }

        let alignment = SensorAlignment(
            currentPitch: sensorManager.currentPitch,
            currentRoll: sensorManager.currentRoll,
            currentHeading: sensorManager.currentHeading,
            targetPitch: beforePitch,
            targetRoll: beforeRoll,
            targetHeading: beforeHeading
        )

        if alignment.isPositioning, !ghostAutoActivated {
            ghostOpacity = ghostDefaultOpacity
            ghostAutoActivated = true
        }

        wasAligned = alignment.isAligned
    }

    func handleSaveResult(_ result: CameraManager.SaveResult) {
        let snapshot = sensorManager.captureSnapshot()
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        var refImagePath: String?
        if result.isBefore {
            refImagePath = saveReferenceImage(
                projectId: project.id,
                pairId: result.pairId,
                filePath: result.filePath,
                docsURL: docsURL
            )
        }

        let photo = Photo(
            filePath: result.filePath,
            thumbnailPath: result.thumbnailPath,
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            altitude: snapshot.altitude,
            heading: snapshot.heading,
            pitch: snapshot.pitch,
            roll: snapshot.roll,
            yaw: snapshot.yaw,
            depthAtCenter: result.isBefore ? depthService.centerDepth : nil,
            relativeAltitude: snapshot.relativeAltitude,
            referenceImagePath: refImagePath,
            focalLength: result.isBefore ? depthService.focalLengthPixels : nil
        )
        modelContext.insert(photo)

        if result.isBefore {
            if let pair = project.pairs.first(where: { $0.id == result.pairId }) {
                pair.beforePhoto = photo
                pair.status = .pendingAfter
            }
        } else if let pair = existingPair, pair.id == result.pairId {
            pair.afterPhoto = photo
            pair.status = .complete
        }
    }

    func saveReferenceImage(
        projectId: UUID,
        pairId: UUID,
        filePath: String,
        docsURL: URL
    ) -> String? {
        let sourceURL = docsURL.appendingPathComponent(filePath)
        guard let sourceImage = UIImage(contentsOfFile: sourceURL.path) else { return nil }

        let maxDim: CGFloat = 540
        let scale = min(maxDim / sourceImage.size.width, maxDim / sourceImage.size.height, 1.0)
        let newSize = CGSize(
            width: sourceImage.size.width * scale,
            height: sourceImage.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let downscaled = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        guard let jpegData = downscaled.jpegData(compressionQuality: 0.85) else { return nil }

        let refDir = docsURL
            .appendingPathComponent("projects")
            .appendingPathComponent(projectId.uuidString)
            .appendingPathComponent("pairs")
            .appendingPathComponent(pairId.uuidString)

        let refURL = refDir.appendingPathComponent("reference.jpg")
        try? jpegData.write(to: refURL, options: .atomic)

        return "projects/\(projectId.uuidString)/pairs/\(pairId.uuidString)/reference.jpg"
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, configurations: config)
        let project = Project(title: "미리보기 현장")
        container.mainContext.insert(project)
        return AnyView(
            PairCameraView(project: project, sensorManager: SensorManager())
                .modelContainer(container)
        )
    } catch {
        return AnyView(Text("미리보기 오류: \(error.localizedDescription)"))
    }
}
