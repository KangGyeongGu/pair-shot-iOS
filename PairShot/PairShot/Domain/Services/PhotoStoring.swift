import Foundation

protocol PhotoStoring: Sendable {
    func saveBeforeJPEG(_ jpegData: Data, fileName: String) throws -> String
    func saveAfterJPEG(_ jpegData: Data, fileName: String) throws -> String
    func saveCombinedJPEG(_ jpegData: Data, fileName: String) throws -> String
    func resolveBefore(fileName: String) -> URL?
    func resolveAfter(fileName: String) -> URL?
    func resolveCombined(fileName: String) -> URL?
    func deletePhotosForPair(
        beforeFileName: String?,
        afterFileName: String?,
        combinedFileName: String?
    )
}
