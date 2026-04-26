import Foundation

protocol ExifNormalizing: Sendable {
    func normalize(_ data: Data, jpegQuality: Double) async -> Data
}
