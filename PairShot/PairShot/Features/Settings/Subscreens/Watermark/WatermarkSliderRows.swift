import SwiftUI

struct WatermarkOpacitySlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_opacity"))
                Spacer()
                Text(verbatim: "\(Int((value * 100).rounded()))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: WatermarkSettings.opacityRange)
        }
    }
}

struct WatermarkLogoAlphaSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_logo_alpha"))
                Spacer()
                Text(verbatim: "\(Int((value * 100).rounded()))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: WatermarkSettings.logoAlphaRange)
        }
    }
}

struct WatermarkTextSizeSlider: View {
    @Binding var value: Double

    private var normalizedBinding: Binding<Double> {
        let low = WatermarkSettings.textSizeRatioRange.lowerBound
        let span = WatermarkSettings.textSizeRatioRange.upperBound - low
        return Binding(
            get: { (1.0 + (value - low) / span * 99.0).rounded() },
            set: { value = low + ($0 - 1.0) / 99.0 * span },
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_text_size"))
                Spacer()
                Text(verbatim: "\(Int(normalizedBinding.wrappedValue))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: normalizedBinding, in: 1 ... 100, step: 1)
        }
    }
}

struct WatermarkLineCountSlider: View {
    @Binding var value: Int

    private var doubleBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { value = Int($0.rounded()) },
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_lines"))
                Spacer()
                Text(verbatim: "\(value)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: doubleBinding,
                in: Double(
                    WatermarkSettings.lineCountRange.lowerBound,
                ) ...
                    Double(WatermarkSettings.lineCountRange.upperBound),
                step: 1,
            )
        }
    }
}

struct WatermarkRepeatSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_repeat"))
                Spacer()
                Text(verbatim: String(format: "%.1fx", value))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $value,
                in: WatermarkSettings.repeatCountRange,
                step: 0.1,
            )
        }
    }
}

struct WatermarkLogoSizeSlider: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "watermark_field_logo_size"))
                Spacer()
                Text(verbatim: "\(Int((value * 100).rounded()))%")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $value,
                in: WatermarkSettings.logoWidthRatioRange,
            )
        }
    }
}
