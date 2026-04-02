@preconcurrency import ARKit
import SwiftData
import SwiftUI
import UIKit

struct ARCameraView: View {
    let project: Project
    var existingPair: PhotoPair?

    var isBefore: Bool {
        existingPair == nil
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var arManager = ARSessionManager()
    @State private var capturedPhoto: UIImage?
    @State private var beforeImage: UIImage?
    @State private var ghostOpacity: Double = 0.0
    @State private var ghostVisible: Bool = false
    @State private var showQualityAlert = false
    @State private var qualityIssueMessage = ""
    @State private var qualityCheckService = QualityCheckService()
    @State private var isSaving = false

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

                        if arManager.savedTransform != nil, !arManager.isFullyAligned {
                            SixDOFGuideView(
                                positionDelta: arManager.positionDelta,
                                orientationDelta: arManager.orientationDelta,
                                positionThreshold: arManager.positionThreshold,
                                orientationThreshold: Float(0.035),
                                isPositionMatched: arManager.isPositionMatched,
                                isOrientationMatched: arManager.isOrientationMatched
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
        .task {
            if !isBefore, let wmPath = existingPair?.beforePhoto?.worldMapPath {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let wmURL = docsURL.appendingPathComponent(wmPath)
                if let worldMap = try? arManager.loadWorldMap(from: wmURL) {
                    arManager.startSession(withWorldMap: worldMap)
                } else {
                    arManager.startSession()
                }
            } else {
                arManager.startSession()
            }

            if !isBefore {
                restoreSavedPose()
            }

            if !isBefore, let filePath = existingPair?.beforePhoto?.filePath {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fullURL = docsURL.appendingPathComponent(filePath)
                if let image = UIImage(contentsOfFile: fullURL.path) {
                    beforeImage = image.downscaledTo1080p()
                    ghostOpacity = 0.35
                    ghostVisible = true
                }
            }
        }
        .onDisappear {
            arManager.stopSession()
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

    @ViewBuilder
    private var trackingStatusBadge: some View {
        switch arManager.trackingState {
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

    private func handleCapture() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let (image, transform, euler) = try await arManager.capturePhoto()
            capturedPhoto = image
            let (pair, pairId) = try resolvePair()
            let photo = try savePhotoFiles(image: image, transform: transform, pairId: pairId)
            var eulerCopy = euler
            photo.arEulerData = Data(bytes: &eulerCopy, count: MemoryLayout<simd_float3>.size)
            photo.pitch = Double(euler.x)
            photo.roll = Double(euler.z)
            photo.yaw = Double(euler.y)
            modelContext.insert(photo)
            await applyPhotoToPair(pair: pair, photo: photo, image: image, pairId: pairId)
        } catch {
            // Capture failed — user can retry
        }
    }

    private func resolvePair() throws -> (PhotoPair, UUID) {
        if isBefore {
            let pair = PhotoPair(project: project)
            modelContext.insert(pair)
            project.pairs.append(pair)
            return (pair, pair.id)
        }
        guard let existing = existingPair else { throw ARSessionError.sessionNotRunning }
        return (existing, existing.id)
    }

    private func savePhotoFiles(
        image: UIImage,
        transform: simd_float4x4,
        pairId: UUID
    ) throws -> Photo {
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
        if let data = image.jpegData(compressionQuality: 0.9) {
            try data.write(to: photoURL)
        }
        let thumbImage = image.arThumbnailImage(maxDimension: 300)
        if let thumbData = thumbImage.jpegData(compressionQuality: 0.8) {
            try thumbData.write(to: thumbURL)
        }
        var transformCopy = transform
        let transformData = Data(bytes: &transformCopy, count: MemoryLayout<simd_float4x4>.size)
        return Photo(
            filePath: photoPath,
            thumbnailPath: thumbPath,
            arTransformData: transformData
        )
    }

    private func applyPhotoToPair(pair: PhotoPair, photo: Photo, image: UIImage, pairId: UUID) async {
        if isBefore {
            pair.beforePhoto = photo
            pair.status = .pendingAfter
            await saveWorldMap(for: photo, pairId: pairId)
        } else {
            pair.afterPhoto = photo
            pair.status = .complete
            await runQualityCheck(on: image, pair: pair)
        }
    }

    private func restoreSavedPose() {
        guard let beforePhoto = existingPair?.beforePhoto else { return }
        if let transformData = beforePhoto.arTransformData,
           transformData.count == MemoryLayout<simd_float4x4>.size
        {
            let transform = transformData.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
            if let eulerData = beforePhoto.arEulerData,
               eulerData.count == MemoryLayout<simd_float3>.size
            {
                let euler = eulerData.withUnsafeBytes { $0.load(as: simd_float3.self) }
                arManager.setSavedPose(transform: transform, eulerAngles: euler)
            } else {
                arManager.setSavedPose(transform: transform, eulerAngles: .zero)
            }
        }
    }

    private func runQualityCheck(on image: UIImage, pair _: PhotoPair) async {
        let issue = await qualityCheckService.analyze(image, isLowLight: false)
        guard let issue else { return }
        switch issue {
            case .blurry:
                qualityIssueMessage = "흐린 사진이 감지되었습니다. 재촬영하시겠습니까?"
            case .overExposed:
                qualityIssueMessage = "과다 노출이 감지되었습니다. 재촬영하시겠습니까?"
            case .underExposed:
                qualityIssueMessage = "노출 부족이 감지되었습니다. 재촬영하시겠습니까?"
        }
        showQualityAlert = true
    }

    private func saveWorldMap(for photo: Photo, pairId: UUID) async {
        // arTransformData/arEulerData는 savePhotoFiles에서 캡처 시점 값으로 이미 저장됨
        // worldMap 저장 시도 (최대 3초 대기)
        for _ in 0 ..< 30 {
            if arManager.worldMappingStatus == .mapped { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard arManager.worldMappingStatus == .mapped || arManager.worldMappingStatus == .extending else { return }
        do {
            let worldMap = try await arManager.captureWorldMap()
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let wmPath = "projects/\(project.id)/pairs/\(pairId)/worldmap.arworldmap"
            let wmURL = docsURL.appendingPathComponent(wmPath)
            try FileManager.default.createDirectory(
                at: wmURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try arManager.saveWorldMap(worldMap, to: wmURL)
            photo.worldMapPath = wmPath
        } catch {
            // WorldMap 저장 실패 — transform 기반 가이드만 동작
        }
    }
}

private extension UIImage {
    func arThumbnailImage(maxDimension: CGFloat) -> UIImage {
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
