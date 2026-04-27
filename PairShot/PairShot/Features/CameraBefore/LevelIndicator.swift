import SwiftUI

struct LevelIndicator: View {
    let rollDegrees: Double
    var tolerance: Double = 1.5

    private var rounded: Int {
        Int(rollDegrees.rounded())
    }

    private var isLevel: Bool {
        abs(rollDegrees) <= tolerance
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "level")
                .imageScale(.small)
            Text(label)
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(.white)
        .background(
            Capsule().fill((isLevel ? Color.appSnackbarSuccess : Color.black).opacity(0.55))
        )
        .accessibilityLabel(String(localized: "camera_settings_level"))
        .accessibilityValue(label)
    }

    private var label: String {
        let prefix = rounded > 0 ? "+" : ""
        return "\(prefix)\(rounded)°"
    }
}

#Preview {
    VStack(spacing: 12) {
        LevelIndicator(rollDegrees: 0)
        LevelIndicator(rollDegrees: 1.2)
        LevelIndicator(rollDegrees: 7.0)
        LevelIndicator(rollDegrees: -12.5)
    }
    .padding()
    .background(Color.appOnSurfaceVariant)
}
