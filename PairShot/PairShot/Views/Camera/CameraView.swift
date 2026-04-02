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

    @State private var cameraManager = CameraManager()
    @State private var cameraSettings = CameraSettings()
    @State private var hapticService = HapticService()
    @State private var lowLightManager = LowLightManager()
    @State private var sensorManager = SensorManager()

    @State private var captureCount: Int = 0
    @State private var timerCountdown: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var isMenuExpanded: Bool = false
    @State private var pinchBaseZoom: CGFloat = 1.0
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    @State private var focusIndicatorScale: CGFloat = 1.0
    @State private var focusIndicatorOpacity: CGFloat = 1.0
    @State private var focusHideTask: Task<Void, Never>?
    @State private var exposureBias: Float = 0
    @State private var isDraggingExposure = false
    @State private var exposureDragStartY: CGFloat = 0
    @State private var exposureBiasAtDragStart: Float = 0
    @State private var ghostOpacity: Double = 0.4
    @State private var beforeImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
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

                        if !isBefore {
                            GhostOverlayView(beforeImage: beforeImage, opacity: $ghostOpacity)

                            if let target = existingPair?.beforePhoto,
                               target.pitch != nil
                            {
                                SensorGuideView(
                                    currentPitch: sensorManager.currentPitch,
                                    currentRoll: sensorManager.currentRoll,
                                    currentYaw: sensorManager.currentYaw,
                                    targetPitch: target.pitch ?? 0,
                                    targetRoll: target.roll ?? 0,
                                    targetYaw: target.yaw ?? 0
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .allowsHitTesting(false)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
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
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        focusIndicatorOpacity = 0.3
                                    }
                                }
                                focusIndicatorOpacity = 1.0
                            }
                    )
                    // 포커스 후 세로 드래그로 노출 조절
                    .simultaneousGesture(
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
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        focusIndicatorOpacity = 0.3
                                    }
                                }
                            }
                    )
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .padding(12)
                }

                // 셔터 버튼: 프리뷰 바로 아래, 자기 크기만큼만
                VStack(spacing: 0) {
                    if lowLightManager.isTorchActive {
                        torchIndicator.padding(.top, 4)
                    }

                    ShutterButton { handleShutterTap() }
                        .padding(.vertical, 12)
                }
                .background(Color.black)

                // 최하단 행: safe area 하단에 고정
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
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -30 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuExpanded = true
                        }
                    }
                }
        )
        .overlay {
            if isMenuExpanded {
                menuPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if isTimerRunning, timerCountdown > 0 {
                timerCountdownOverlay
            }
        }
        .task {
            await startCamera()
            if !isBefore, let filePath = existingPair?.beforePhoto?.filePath {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fullURL = docsURL.appendingPathComponent(filePath)
                if let image = UIImage(contentsOfFile: fullURL.path) {
                    beforeImage = image.downscaledTo1080p()
                }
            }
        }
        .onAppear {
            sensorManager.startUpdates()
            if !isBefore, existingPair?.beforePhoto?.pitch != nil {
                hapticService.startContinuousHaptic()
            }
        }
        .onDisappear {
            hapticService.stopHaptic()
            sensorManager.stopUpdates()
            cameraManager.stopSession()
        }
        .onChange(of: sensorManager.currentPitch) { _, _ in
            guard !isBefore, let alignment = sensorAlignment else { return }
            if alignment.stage == .aligning, alignment.isAligned {
                hapticService.triggerSuccess()
                hapticService.stopHaptic()
            } else {
                hapticService.updateIntensity(alignmentScore: alignment.alignmentScore)
            }
        }
        .onChange(of: cameraManager.saveResult) { _, result in
            if let result {
                handleSaveResult(result)
            }
        }
        .onChange(of: cameraManager.isSessionRunning) { _, running in
            if running {
                let info = cameraManager.getZoomInfo()
                // 다이얼용: 기기의 모든 고정 배율 (기기별 동적)
                cameraSettings.allFixedFactors = info.allFixedFactors
                cameraSettings.focalLengthMap = info.focalLengthMap
                // 버튼용: 항상 0.5x, 1x, 2x, 3x 고정 (displayMultiplier 기반으로 내부값 계산)
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
        }
        .onChange(of: cameraManager.capturedPhoto) { _, newPhoto in
            if newPhoto != nil { captureCount += 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.subjectAreaDidChangeNotification)) { _ in
            cameraManager.resetFocusAndExposure()
            showFocusIndicator = false
        }
    }
}

extension CameraView {
    private var sensorAlignment: SensorAlignment? {
        guard let target = existingPair?.beforePhoto,
              let tPitch = target.pitch,
              let tRoll = target.roll,
              let tYaw = target.yaw
        else { return nil }
        return SensorAlignment(
            currentPitch: sensorManager.currentPitch,
            currentRoll: sensorManager.currentRoll,
            currentYaw: sensorManager.currentYaw,
            targetPitch: tPitch,
            targetRoll: tRoll,
            targetYaw: tYaw
        )
    }

    private var torchIndicator: some View {
        HStack(spacing: 4) {
            Circle().fill(.yellow).frame(width: 6, height: 6)
            Text("저조도 보정").font(.system(size: 11)).foregroundStyle(.yellow)
        }
    }

    private var captureCountLabel: some View {
        Group {
            if captureCount > 0 {
                Text("\(captureCount)장 촬영")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("PHOTO")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.yellow)
            }
        }
    }

    private var thumbnailView: some View {
        Group {
            if let photo = cameraManager.capturedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
            } else {
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 48, height: 48)
            }
        }
    }

    private var cameraSwitchButton: some View {
        Button {
            cameraManager.switchCamera()
            cameraSettings.setFrontCamera(!cameraSettings.isUsingFrontCamera)
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var menuPanel: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.4)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isMenuExpanded = false
                    }
                }

            CameraControlBar(
                flashMode: Binding(get: { cameraSettings.flashMode }, set: { _ in cameraSettings.cycleFlashMode() }),
                aspectRatio: Binding(
                    get: { cameraSettings.currentAspectRatio },
                    set: { _ in cameraSettings.cycleAspectRatio() }
                ),
                isGridEnabled: Binding(
                    get: { cameraSettings.isGridEnabled },
                    set: { _ in cameraSettings.toggleGrid() }
                ),
                timerDuration: Binding(
                    get: { cameraSettings.timerDuration },
                    set: { _ in cameraSettings.cycleTimer() }
                ),
                onFlashTap: { cameraSettings.cycleFlashMode() },
                onRatioTap: { cameraSettings.cycleAspectRatio() },
                onGridTap: { cameraSettings.toggleGrid() },
                onTimerTap: { cameraSettings.cycleTimer() }
            )
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 30 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isMenuExpanded = false
                            }
                        }
                    }
            )
        }
    }

    private var timerCountdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            Text("\(timerCountdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let factor = pinchBaseZoom * value
                cameraManager.setZoomDirect(factor: factor)
                cameraSettings.currentZoomFactor = factor
            }
            .onEnded { _ in
                pinchBaseZoom = cameraSettings.currentZoomFactor
            }
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

    private func handleSaveResult(_ result: CameraManager.SaveResult) {
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
            }
        } else if let pair = existingPair, pair.id == result.pairId {
            pair.afterPhoto = photo
            pair.status = .complete
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
