import Foundation

enum ExportTutorialStepCopy {
    static func textKey(for step: ExportTutorialStep) -> String.LocalizationValue {
        switch step {
            case .includes: "tutorial_msg_export_include"
            case .format: "tutorial_msg_export_format"
            case .watermark: "tutorial_msg_export_watermark"
            case .combine: "tutorial_msg_export_combine"
        }
    }

    static func text(for step: ExportTutorialStep) -> String {
        String(localized: textKey(for: step))
    }
}
