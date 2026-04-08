@preconcurrency import ARKit
import SwiftData
import SwiftUI
import UIKit

struct ARCameraView: View {
    let project: Project
    let arManager: ARSessionManager
    var existingPair: PhotoPair?

    var isBefore: Bool {
        existingPair == nil
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var capturedPhoto: UIImage?
    @State private var beforeImage: UIImage?
    @State private var ghostOpacity: Double = 0.0
    @State private var ghostVisible: Bool = false
    @State private var isSaving = false
    @State private var didLoadWorldMap = false
    @State private var captureErrorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    ARCameraPreviewView(session: arManager.session)

                    if !isBefore {
                        if let beforeImage, ghostVisible {
                            Image(uiImage: beforeImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .opacity(ghostOpacity)
                                .allowsHitTesting(false)
                        }

                        if arManager.savedTransform != nil, !arManager.isFullyAligned,
                           arManager.trackingState == .normal
                        {
                            SixDOFGuideView(
                                lateralDeltaCm: Double(arManager.positionDelta.x) * 100,
                                heightDeltaCm: Double(arManager.positionDelta.y) * 100,
                                distanceDeltaCm: Double(arManager.positionDelta.z) * 100,
                                yawDeltaDeg: Double(arManager.yawDelta) * 180 / .pi,
                                pitchDeltaDeg: Double(arManager.pitchDelta) * 180 / .pi,
                                rollDeltaDeg: Double(arManager.rollDelta) * 180 / .pi,
                                hasLiDAR: arManager.hasLiDAR,
                                positionThresholdCm: Double(arManager.positionThreshold) * 100,
                                orientationThresholdDeg: Double(arManager.orientationThreshold) * 180 / .pi
                            )
                            .allowsHitTesting(false)
                        }

                        if arManager.isFullyAligned {
                            VStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.green)
                                    .padding(.bottom, 20)
                            }
                            .allowsHitTesting(false)
                        }
                    }

                    if arManager.isSessionRunning {
                        VStack {
                            trackingStatusBadge
                                .padding(.top, 8)
                            Spacer()
                        }
                    }
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
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

                VStack(spacing: 0) {
                    ShutterButton { Task { await handleCapture() } }
                        .padding(.vertical, 12)
                        .disabled(isSaving)
                }
                .background(Color.black)

                HStack {
                    if let photo = capturedPhoto {
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
                    Spacer()
                    Text(isBefore ? "BEFORE" : "AFTER")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Spacer()
                    Color.clear.frame(width: 48, height: 48)
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.black)
            }
        }
        .statusBarHidden(true)
        .alert("촬영 실패", isPresented: Binding(
            get: { captureErrorMessage != nil },
            set: { if !$0 { captureErrorMessage = nil } }
        )) {
            Button("확인") { captureErrorMessage = nil }
        } message: {
            Text(captureErrorMessage ?? "")
        }
        .task {
            if !arManager.isSessionRunning {
                await startARSession()
            }

            if !isBefore {
                restoreSavedPose()
            }

            if !isBefore, let filePath = existingPair?.beforePhoto?.filePath {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fullURL = docsURL.appendingPathComponent(filePath)
                let loaded = await Task.detached(priority: .userInitiated) {
                    UIImage(contentsOfFile: fullURL.path)?.downscaledTo1080p()
                }.value
                if let loaded {
                    beforeImage = loaded
                    ghostOpacity = 0.35
                    ghostVisible = true
                }
            }
        }
        .onDisappear {
            arManager.stopSession()
        }
    }

    private var trackingStatusBadge: some View {
        ARTrackingStatusBadge(
            isBefore: isBefore,
            worldMappingStatus: arManager.worldMappingStatus,
            trackingState: arManager.trackingState
        )
    }

    private func handleCapture() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            for _ in 0 ..< 30 {
                guard !Task.isCancelled else { return }
                if arManager.trackingState == .normal { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            let result = try await arManager.capturePhoto()
            capturedPhoto = result.image
            let capturedPitch = Double(arManager.pitchDelta)
            let capturedRoll = Double(arManager.rollDelta)
            let capturedYaw = Double(arManager.yawDelta)
            let capturedRelocalized = didLoadWorldMap && arManager.trackingState == .normal
            let (pair, pairId) = try resolvePair()
            let photo = try await savePhotoFiles(result: result, pairId: pairId)
            photo.pitch = capturedPitch
            photo.roll = capturedRoll
            photo.yaw = capturedYaw
            if isBefore {
                await saveWorldMap(to: photo, pairId: pairId)
            } else {
                photo.arRelocalized = capturedRelocalized
            }
            modelContext.insert(photo)
            if isBefore {
                pair.beforePhoto = photo
                pair.status = .pendingAfter
            } else {
                pair.afterPhoto = photo
                pair.status = .complete
                Task { await AIAnalysisCoordinator.analyze(pairID: pair.id, in: modelContext) }
            }
        } catch {
            captureErrorMessage = "촬영에 실패했습니다. 다시 시도해주세요."
        }
    }

    private func saveWorldMap(to photo: Photo, pairId: UUID) async {
        guard arManager.worldMappingStatus == .mapped || arManager.worldMappingStatus == .extending else { return }
        do {
            let worldMap = try await arManager.captureWorldMap()
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let wmRelPath = "projects/\(project.id)/pairs/\(pairId)/worldmap.armap"
            let wmURL = docsURL.appendingPathComponent(wmRelPath)
            try arManager.saveWorldMap(worldMap, to: wmURL)
            photo.worldMapPath = wmRelPath
        } catch {
            // WorldMap 캡처 실패 시 worldMapPath = nil → Tier 2/3 불가, Tier 1 폴백
        }
    }

    private func resolvePair() throws -> (PhotoPair, UUID) {
        if isBefore {
            let pair = PhotoPair(captureMode: .precision, project: project)
            modelContext.insert(pair)
            project.pairs.append(pair)
            return (pair, pair.id)
        }
        guard let existing = existingPair else { throw ARSessionError.sessionNotRunning }
        return (existing, existing.id)
    }

    private func savePhotoFiles(result: ARCaptureResult, pairId: UUID) async throws -> Photo {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let subDir = isBefore ? "before" : "after"
        let photoPath = "projects/\(project.id)/pairs/\(pairId)/\(subDir).jpg"
        let thumbPath = "projects/\(project.id)/thumbs/\(pairId)_\(subDir).jpg"
        let photoURL = docsURL.appendingPathComponent(photoPath)
        let thumbURL = docsURL.appendingPathComponent(thumbPath)
        try FileManager.default.createDirectory(
            at: photoURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: thumbURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )

        let isBeforeCapture = isBefore
        let projectId = project.id
        let sceneDepth = result.sceneDepthMap
        let depthW = result.sceneDepthWidth
        let depthH = result.sceneDepthHeight

        let depthRelPath: String? = try await Task.detached(priority: .userInitiated) {
            if let data = result.image.jpegData(compressionQuality: 0.9) {
                try data.write(to: photoURL)
            }
            let thumb = result.image.arThumbnailImage(maxDimension: 300)
            if let thumbData = thumb.jpegData(compressionQuality: 0.8) {
                try thumbData.write(to: thumbURL)
            }
            guard isBeforeCapture, let depthData = sceneDepth else { return nil }
            let rel = "projects/\(projectId)/pairs/\(pairId)/before_depth_\(depthW)x\(depthH).bin"
            try? depthData.write(to: docsURL.appendingPathComponent(rel))
            return rel
        }.value

        var transformCopy = result.transform
        let transformData = Data(bytes: &transformCopy, count: MemoryLayout<simd_float4x4>.size)

        var intrinsicsCopy = result.intrinsics
        let intrinsicsData = Data(bytes: &intrinsicsCopy, count: MemoryLayout<matrix_float3x3>.size)

        return Photo(
            filePath: photoPath,
            thumbnailPath: thumbPath,
            arTransformData: transformData,
            arIntrinsicsData: intrinsicsData,
            depthMapPath: depthRelPath
        )
    }

    private func startARSession() async {
        guard !isBefore, let wmRelPath = existingPair?.beforePhoto?.worldMapPath else {
            arManager.startSession()
            return
        }
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let wmURL = docsURL.appendingPathComponent(wmRelPath)
        do {
            let worldMap = try arManager.loadWorldMap(from: wmURL)
            arManager.startSession(withWorldMap: worldMap)
            didLoadWorldMap = true
            await waitForRelocalize()
        } catch {
            arManager.startSession()
        }
    }

    private func waitForRelocalize() async {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            guard !Task.isCancelled else { return }
            if arManager.trackingState == .normal { return }
            if case let .limited(reason) = arManager.trackingState, reason != .relocalizing { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
        // 타임아웃 — relocalize 실패, 세션은 계속 (Tier 1 폴백)
    }

    private func restoreSavedPose() {
        guard let beforePhoto = existingPair?.beforePhoto,
              let transformData = beforePhoto.arTransformData,
              transformData.count == MemoryLayout<simd_float4x4>.size
        else { return }
        let transform = transformData.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
        arManager.setSavedPose(transform: transform)
    }
}

private struct ARTrackingStatusBadge: View {
    let isBefore: Bool
    let worldMappingStatus: ARFrame.WorldMappingStatus
    let trackingState: ARCamera.TrackingState

    var body: some View {
        VStack(spacing: 6) {
            if isBefore {
                switch worldMappingStatus {
                    case .limited:
                        Label("AR 맵 구성 중...", systemImage: "map")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.5), in: Capsule())
                    case .notAvailable, .extending, .mapped:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                }
            }
            switch trackingState {
                case .normal:
                    EmptyView()
                case .notAvailable:
                    Label("AR 초기화 중", systemImage: "circle.dashed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                case let .limited(reason):
                    let text = switch reason {
                        case .initializing: "환경 인식 중..."
                        case .relocalizing: "이전 위치 찾는 중..."
                        case .excessiveMotion: "너무 빠르게 움직이고 있습니다"
                        case .insufficientFeatures: "특징점 부족 — 주변을 비춰주세요"
                        @unknown default: "제한적 트래킹"
                    }
                    Label(text, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
            }
        }
    }
}

private extension UIImage {
    nonisolated func arThumbnailImage(maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
