import SwiftData
import SwiftUI

struct UnifiedCameraView: View {
    let project: Project
    var existingPair: PhotoPair?
    let sensorManager: SensorManager

    @Environment(\.dismiss) private var dismiss
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
