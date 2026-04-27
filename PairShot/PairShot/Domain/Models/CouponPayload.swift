import Foundation

nonisolated struct CouponPayload: Codable, Equatable {
    nonisolated enum CodingKeys: String, CodingKey {
        case code
        case kind
        case issuedAt
        case version
    }

    static let currentVersion: Int = 1

    let code: String
    let kind: String
    let issuedAt: Date
    let version: Int
}

nonisolated enum CouponPayloadDecoder {
    static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
