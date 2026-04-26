import Foundation
import UIKit

// Supporting value types for `ExportPicker` (P7.3). Pulled out of the view
// file so the SwiftUI body stays under the 250-line cap from the project
// style guide.

/// Container that the gallery passes to `.sheet(item:)` to present
/// `ExportPicker`. Carries the snapshot of selected pairs at the moment the
/// user tapped 공유 — later mutations to selection don't affect an
/// already-open picker.
struct ExportPickerPayload: Identifiable {
    let id = UUID()
    let pairs: [PhotoPair]
}

/// Phase machine driving the in-picker `ProgressView` overlay. Surfaced as a
/// non-private type so unit tests can assert state transitions without
/// rendering the SwiftUI tree.
enum ExportPickerPhase: Equatable {
    case idle
    case zipping
    case savingToLibrary
    case preparingImages

    var label: String {
        switch self {
            case .idle: ""
            case .zipping: String(localized: "ZIP 생성 중…")
            case .savingToLibrary: String(localized: "사진 앱에 저장 중…")
            case .preparingImages: String(localized: "이미지 준비 중…")
        }
    }
}

/// Activity items handed to `ShareSheet`. `Identifiable` so the picker can
/// trigger presentation via `.sheet(item:)`.
struct ExportShareItems: Identifiable {
    let id = UUID()
    let values: [Any]
}

/// User-visible export-picker error. The `ExportPicker` shows this in an
/// alert; the `id` exists so SwiftUI can drive `.alert(item:)` reactively.
struct ExportPickerError: Identifiable, Equatable {
    let id = UUID()
    let message: String

    static func from(zipError: ZipExporter.ExportError) -> Self {
        switch zipError {
            case .noPairs:
                Self(message: String(localized: "선택된 페어가 없습니다"))

            case .sourceMissing:
                Self(message: String(localized: "원본 파일을 찾을 수 없습니다"))

            case .archiveFailed:
                Self(message: String(localized: "ZIP 생성에 실패했습니다"))
        }
    }
}
