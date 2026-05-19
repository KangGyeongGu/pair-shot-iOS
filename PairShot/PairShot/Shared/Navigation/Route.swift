import Foundation

enum Route: Hashable, Codable {
    case home
    case albumDetail(albumId: UUID)
    case pairPreview(pairId: UUID)
    case settings
    case watermarkSettings
    case combineSettings
    case license
    case businessInfo
    case exportSettings(pairIds: [UUID])
    case languagePicker
    case themePicker
    case imageQualityPicker
    case filenamePrefixEditor
}
