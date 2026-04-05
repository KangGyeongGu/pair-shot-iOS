import OSLog
import SwiftData
import SwiftUI

struct UnifiedCameraView: View {
    let project: Project
    var existingPair: PhotoPair?
    let sensorManager: SensorManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMode: CaptureMode = .precision
    @State private var arManager = ARSessionManager()
    @State private var isSwitching = false

    var isBefore: Bool {
        existingPair == nil
    }

    var isModeLocked: Bool {
        existingPair != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch selectedMode {
                    case .precision:
                        ARCameraView(
                            project: project,
                            arManager: arManager,
                            existingPair: existingPair
                        )
                        .id("precision")
                    case .normal:
                        PairCameraView(
                            project: project,
                            existingPair: existingPair,
                            sensorManager: sensorManager
                        )
                        .id("normal")
                }
            }

            if !isModeLocked {
                VStack {
                    Spacer()
                    modeSwitcher
                        .padding(.bottom, 4)
                }
                .allowsHitTesting(true)
            }

            if isSwitching {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("모드 전환 중...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .task {
            if isModeLocked, let pair = existingPair {
                selectedMode = pair.captureMode
            } else {
                selectedMode = UserDefaults.standard.string(forKey: "lastCaptureMode")
                    .flatMap(CaptureMode.init(rawValue:)) ?? .precision
            }
        }
        .onChange(of: existingPair?.status) { _, newStatus in
            if newStatus == .complete, let pair = existingPair {
                triggerAIAnalysis(for: pair)
            }
        }
    }

    private func triggerAIAnalysis(for pair: PhotoPair) {
        let pairID = pair.id
        let projectID = project.id
        let storage = PhotoStorageService()

        guard
            let beforeURL = try? storage.photoURL(projectId: projectID, pairId: pairID, isBefore: true),
            let afterURL = try? storage.photoURL(projectId: projectID, pairId: pairID, isBefore: false),
            let alignedOutputURL = try? storage.alignedPhotoURL(projectId: projectID, pairId: pairID),
            let correctedOutputURL = try? storage.colorCorrectedPhotoURL(projectId: projectID, pairId: pairID)
        else { return }

        let logger = Logger(subsystem: "com.pairshot", category: "AIAnalysis")

        Task {
            async let alignedURL: URL? = {
                do {
                    return try await AlignmentService.align(
                        beforeURL: beforeURL,
                        afterURL: afterURL,
                        outputURL: alignedOutputURL
                    )
                } catch {
                    logger.error("AlignmentService failed: \(error)")
                    return nil
                }
            }()
            async let distance: Float? = {
                do {
                    return try await MatchingScoreService.computeDistance(
                        beforeURL: beforeURL,
                        afterURL: afterURL
                    )
                } catch {
                    logger.error("MatchingScoreService failed: \(error)")
                    return nil
                }
            }()
            async let correctedURL: URL? = {
                do {
                    return try await ColorCorrectionService.correct(
                        beforeURL: beforeURL,
                        referenceAfterURL: afterURL,
                        outputURL: correctedOutputURL
                    )
                } catch {
                    logger.error("ColorCorrectionService failed: \(error)")
                    return nil
                }
            }()

            let (aligned, score, corrected) = await (alignedURL, distance, correctedURL)

            let descriptor = FetchDescriptor<PhotoPair>(predicate: #Predicate { $0.id == pairID })
            guard let fetched = try? modelContext.fetch(descriptor).first else { return }
            fetched.alignedBeforeImagePath = aligned?.path
            fetched.matchingScore = score
            fetched.colorCorrectedBeforeImagePath = corrected?.path
            try? modelContext.save()
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button {
                    guard mode != selectedMode else { return }
                    switchMode(to: mode)
                } label: {
                    Text(mode.label)
                        .font(.system(size: 13, weight: selectedMode == mode ? .bold : .medium))
                        .foregroundStyle(selectedMode == mode ? .yellow : .white.opacity(0.6))
                        .frame(width: 72, height: 32)
                        .background(
                            selectedMode == mode
                                ? Color.white.opacity(0.15)
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.black.opacity(0.5), in: Capsule())
    }

    private func switchMode(to mode: CaptureMode) {
        isSwitching = true
        selectedMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "lastCaptureMode")
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            isSwitching = false
        }
    }
}
