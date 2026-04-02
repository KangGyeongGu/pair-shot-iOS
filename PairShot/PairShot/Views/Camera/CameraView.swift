@preconcurrency import ARKit
import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct CameraView: View {
    let project: Project
    var existingPair: PhotoPair?

    var isBefore: Bool {
        existingPair == nil
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var cameraManager = CameraManager()
    @State var cameraSettings = CameraSettings()
    @State var hapticService = HapticService()
    @State var lowLightManager = LowLightManager()
    @State private var sensorManager = SensorManager()

    @State var captureCount: Int = 0
    @State var timerCountdown: Int = 0
    @State var isTimerRunning: Bool = false
    @State var isMenuExpanded: Bool = false
    @State var pinchBaseZoom: CGFloat = 1.0
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    @State private var focusIndicatorScale: CGFloat = 1.0
    @State private var focusIndicatorOpacity: CGFloat = 1.0
    @State private var focusHideTask: Task<Void, Never>?
    @State private var exposureBias: Float = 0
    @State private var isDraggingExposure = false
    @State private var exposureDragStartY: CGFloat = 0
    @State private var exposureBiasAtDragStart: Float = 0
    @State private var ghostOpacity: Double = 0.0
    @State private var ghostAutoActivated: Bool = false
    @State private var ghostDefaultOpacity: Double = 0.15
    @State private var beforeImage: UIImage?
    @State var arSessionManager = ARSessionManager()
    @State var isARRelocalized = false
    @State var qualityCheckService = QualityCheckService()
    @State var showQualityAlert = false
    @State var qualityIssueMessage = ""
    @State var lidarStartPoint: CGPoint?
    @State var lidarEndPoint: CGPoint?
    @State var lidarDistance: Float?
    @State var lidarStartWorldPos: SIMD3<Float>?
    @State var isMeasureMode: Bool = false
    @State private var wasAligned = false

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
        .task { await loadCameraAndMap() }
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
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.subjectAreaDidChangeNotification)) { _ in
            cameraManager.resetFocusAndExposure()
            showFocusIndicator = false
        }
        .onChange(of: arSessionManager.worldMappingStatus) { _, status in
            if status == .mapped, !isARRelocalized { isARRelocalized = true }
        }
        .onChange(of: arSessionManager.isPositionMatched) { _, matched in
            if matched { hapticService.triggerSuccess() }
        }
        .alert("촬영 품질", isPresented: $showQualityAlert) {
            Button("재촬영", role: .destructive) {
                if let pair = existingPair {
                    pair.afterPhoto = nil
                    pair.status = .pendingAfter
                }
            }
            Button("저장", role: .cancel) {}
        } message: {
            Text(qualityIssueMessage)
        }
    }
}

extension CameraView {
    private var cameraPreviewSection: some View {
        GeometryReader { previewGeo in
            ZStack {
                CameraPreviewView(
                    previewLayer: cameraManager.previewLayer,
                    aspectRatio: cameraSettings.currentAspectRatio
                )
                .gesture(pinchGesture)
                GridOverlayView(isGridEnabled: cameraSettings.isGridEnabled)
                LevelIndicatorView(previewWidth: previewGeo.size.width)
                if !cameraManager.isCameraAuthorized, !cameraManager.isSessionRunning {
                    PermissionDeniedView.camera
                }
                if showFocusIndicator, let point = focusPoint {
                    FocusIndicatorView(
                        exposureBias: exposureBias,
                        exposureBiasMax: cameraManager.getExposureBiasRange().max,
                        isDraggingExposure: isDraggingExposure,
                        scale: focusIndicatorScale,
                        opacity: focusIndicatorOpacity
                    )
                    .position(point)
                }
                if !isBefore { afterModeOverlays }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(tapGesture)
            .simultaneousGesture(exposureDragGesture)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay {
            ZoomControlView(
                availableFactors: cameraSettings.availableZoomFactors,
                allFixedFactors: cameraSettings.allFixedFactors,
                focalLengthMap: cameraSettings.focalLengthMap,
                currentFactor: cameraSettings.currentZoomFactor,
                minFactor: cameraSettings.minZoomFactor,
                maxFactor: cameraSettings.maxZoomFactor,
                zoomDivisor: cameraSettings.zoomDivisor,
                onZoomChanged: { factor in
                    cameraManager.setZoom(factor: factor)
                    cameraSettings.currentZoomFactor = factor
                },
                onZoomDrag: { factor in
                    cameraManager.setZoomDirect(factor: factor)
                    cameraSettings.currentZoomFactor = factor
                }
            )
        }
        .clipped()
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            if !isBefore, arSessionManager.hasLiDAR {
                Button {
                    isMeasureMode.toggle()
                    if !isMeasureMode {
                        lidarStartPoint = nil
                        lidarEndPoint = nil
                        lidarDistance = nil
                        lidarStartWorldPos = nil
                    }
                } label: {
                    Image(systemName: isMeasureMode ? "ruler.fill" : "ruler")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isMeasureMode ? .yellow : .white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder var afterModeOverlays: some View {
        GhostOverlayView(beforeImage: beforeImage, opacity: $ghostOpacity)
        if ghostOpacity > 0 {
            GhostOpacitySlider(opacity: $ghostOpacity) { newValue in
                ghostDefaultOpacity = newValue
            }
        }
        if let target = existingPair?.beforePhoto, target.heading != nil {
            SensorGuideView(
                currentPitch: sensorManager.currentPitch,
                currentRoll: sensorManager.currentRoll,
                currentHeading: sensorManager.currentHeading,
                targetPitch: target.pitch ?? 0,
                targetRoll: target.roll ?? 0,
                targetHeading: target.heading ?? 0
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)
        }
        if isARRelocalized, !arSessionManager.isPositionMatched {
            ARPositionGuideView(
                positionDelta: arSessionManager.positionDelta,
                threshold: arSessionManager.positionThreshold,
                isPositionMatched: arSessionManager.isPositionMatched
            )
            .allowsHitTesting(false)
        }
        if arSessionManager.hasLiDAR {
            LiDARMeasureOverlayView(
                startPoint: lidarStartPoint,
                endPoint: lidarEndPoint,
                distance: lidarDistance
            )
        }
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                if !isBefore, isMeasureMode {
                    handleMeasureTap(at: value.location)
                    return
                }
                if !isBefore, ghostAutoActivated {
                    ghostOpacity = ghostOpacity > 0 ? 0.0 : ghostDefaultOpacity
                }
                let location = value.location
                cameraManager.focusAndExpose(at: location)
                focusPoint = location
                showFocusIndicator = true
                focusIndicatorScale = 1.2
                exposureBias = 0
                cameraManager.setExposureBias(0)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    focusIndicatorScale = 1.0
                }
                focusHideTask?.cancel()
                focusHideTask = Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    withAnimation(.easeOut(duration: 0.5)) { focusIndicatorOpacity = 0.3 }
                }
                focusIndicatorOpacity = 1.0
            }
    }

    /// 포커스 후 세로 드래그로 노출 조절
    private var exposureDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if !isDraggingExposure {
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    guard showFocusIndicator || focusPoint != nil else { return }
                    isDraggingExposure = true
                    exposureDragStartY = value.startLocation.y
                    exposureBiasAtDragStart = exposureBias
                    showFocusIndicator = true
                    focusIndicatorOpacity = 1.0
                }
                focusHideTask?.cancel()
                let dragDelta = exposureDragStartY - value.location.y
                let range = cameraManager.getExposureBiasRange()
                let deltaEV = Float(dragDelta / 2400.0) * (range.max - range.min)
                let newBias = max(range.min, min(exposureBiasAtDragStart + deltaEV, range.max))
                exposureBias = newBias
                cameraManager.setExposureBias(newBias)
                focusIndicatorOpacity = 1.0
            }
            .onEnded { _ in
                isDraggingExposure = false
                focusHideTask = Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    withAnimation(.easeOut(duration: 0.5)) { focusIndicatorOpacity = 0.3 }
                }
            }
    }

    var sensorAlignment: SensorAlignment? {
        guard let target = existingPair?.beforePhoto,
              let tPitch = target.pitch,
              let tRoll = target.roll,
              let tHeading = target.heading
        else { return nil }
        return SensorAlignment(
            currentPitch: sensorManager.currentPitch,
            currentRoll: sensorManager.currentRoll,
            currentHeading: sensorManager.currentHeading,
            targetPitch: tPitch,
            targetRoll: tRoll,
            targetHeading: tHeading
        )
    }

    func startCamera() async {
        let granted = await cameraManager.requestAuthorization()
        guard granted else { return }
        cameraManager.startSession()
    }

    func handleShutterTap() {
        if cameraSettings.timerDuration == .off {
            fireCapture()
        } else {
            startTimerCapture()
        }
    }

    private func fireCapture() {
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

    private func loadCameraAndMap() async {
        await startCamera()
        if !isBefore, let filePath = existingPair?.beforePhoto?.filePath {
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fullURL = docsURL.appendingPathComponent(filePath)
            if let image = UIImage(contentsOfFile: fullURL.path) {
                beforeImage = image.downscaledTo1080p()
            }
        }
        await loadWorldMapIfNeeded()
    }

    private func onViewAppear() {
        sensorManager.startUpdates()
        if !isBefore, existingPair?.beforePhoto?.pitch != nil {
            hapticService.startContinuousHaptic()
        }
    }

    private func onViewDisappear() {
        hapticService.stopHaptic()
        sensorManager.stopUpdates()
        cameraManager.stopSession()
        arSessionManager.stopSession()
    }

    private func handleSensorUpdate() {
        guard !isBefore, let alignment = sensorAlignment else { return }
        if alignment.isPositioning, !ghostAutoActivated {
            ghostOpacity = ghostDefaultOpacity
            ghostAutoActivated = true
        }
        if alignment.isAligned {
            if !wasAligned {
                hapticService.triggerSuccess()
                hapticService.stopHaptic()
                wasAligned = true
            }
        } else {
            if wasAligned {
                hapticService.startContinuousHaptic()
                wasAligned = false
            }
            hapticService.updateIntensity(alignmentScore: alignment.alignmentScore)
        }
    }

    private func applyZoomInfo() {
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

    func handleSaveResult(_ result: CameraManager.SaveResult) {
        let snapshot = sensorManager.captureSnapshot()
        let photo = Photo(
            filePath: result.filePath,
            thumbnailPath: result.thumbnailPath,
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            altitude: snapshot.altitude,
            heading: snapshot.heading,
            pitch: snapshot.pitch,
            roll: snapshot.roll,
            yaw: snapshot.yaw
        )
        modelContext.insert(photo)

        if result.isBefore {
            if let pair = project.pairs.first(where: { $0.id == result.pairId }) {
                pair.beforePhoto = photo
                pair.status = .pendingAfter
                // ARWorldMap 저장은 비활성화 — ARSession이 AVCaptureSession을 방해하여 프리뷰 끊김
                // TODO: 카메라 종료 후 별도 흐름에서 worldMap 저장 구현
            }
        } else if let pair = existingPair, pair.id == result.pairId {
            pair.afterPhoto = photo
            pair.status = .complete
            if let capturedImage = cameraManager.capturedPhoto {
                runQualityCheck(on: capturedImage)
            }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, configurations: config)
        let project = Project(title: "미리보기 현장")
        container.mainContext.insert(project)
        return AnyView(
            CameraView(project: project)
                .modelContainer(container)
        )
    } catch {
        return AnyView(Text("미리보기 오류: \(error.localizedDescription)"))
    }
}
