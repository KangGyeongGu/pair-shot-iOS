import Foundation

enum CaptureMode: String, Codable, CaseIterable {
    case precision
    case normal

    var label: String {
        switch self {
            case .precision: "정밀"
            case .normal: "일반"
        }
    }

    var iconName: String {
        switch self {
            case .precision: "scope"
            case .normal: "camera.fill"
        }
    }
}
