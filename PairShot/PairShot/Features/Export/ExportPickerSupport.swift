import Foundation
import UIKit

struct ExportPickerPayload: Identifiable {
    let id = UUID()
    let pairs: [PhotoPair]
}

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

struct ExportShareItems: Identifiable {
    let id = UUID()
    let values: [Any]
}

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

    static func from(useCaseError: ExportPairsUseCase.ExportError) -> Self {
        switch useCaseError {
            case .noPairs:
                Self(message: String(localized: "선택된 페어가 없습니다"))

            case .unsupportedFormat:
                Self(message: String(localized: "ZIP 생성에 실패했습니다"))
        }
    }
}
