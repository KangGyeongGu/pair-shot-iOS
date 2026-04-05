import CoreHaptics
import UIKit

@MainActor
@Observable
final class HapticService {
    private var engine: CHHapticEngine?
    private var player: (any CHHapticAdvancedPatternPlayer)?
    private let supportsHaptics: Bool

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else { return }
        do {
            let hapticEngine = try CHHapticEngine()
            hapticEngine.playsHapticsOnly = true
            hapticEngine.stoppedHandler = { [weak hapticEngine] reason in
                guard reason != .engineDestroyed else { return }
                Task { @MainActor in
                    try? await hapticEngine?.start()
                }
            }
            hapticEngine.resetHandler = { [weak hapticEngine] in
                Task { @MainActor in
                    try? await hapticEngine?.start()
                }
            }
            engine = hapticEngine
        } catch {
            engine = nil
        }
    }

    func startContinuousHaptic() {
        guard supportsHaptics, let engine else {
            fallbackImpact(intensity: 0.3)
            return
        }
        do {
            try engine.start()
            let intensity = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: 0.3
            )
            let sharpness = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: 0.2
            )
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: 0,
                duration: 30
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let newPlayer = try engine.makeAdvancedPlayer(with: pattern)
            newPlayer.loopEnabled = true
            try newPlayer.start(atTime: CHHapticTimeImmediate)
            player = newPlayer
        } catch {
            player = nil
        }
    }

    static func clampedIntensity(_ score: Double) -> Float {
        Float(max(0.0, min(1.0 - score, 1.0)))
    }

    func updateIntensity(alignmentScore: Double) {
        guard supportsHaptics, let player else {
            if alignmentScore > 0.1 {
                fallbackImpact(intensity: alignmentScore)
            }
            return
        }
        let clamped = Self.clampedIntensity(alignmentScore)
        let param = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: clamped,
            relativeTime: 0
        )
        try? player.sendParameters([param], atTime: CHHapticTimeImmediate)
    }

    func stopHaptic() {
        guard supportsHaptics, let player else { return }
        try? player.stop(atTime: CHHapticTimeImmediate)
        self.player = nil
    }

    func triggerSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func fallbackImpact(intensity: Double) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: intensity)
    }
}
