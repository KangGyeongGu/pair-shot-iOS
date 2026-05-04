import CryptoKit
import Foundation
import UIKit

@MainActor
struct DeviceHashProvider {
    private static let hexCharacters: [Character] = Array("0123456789abcdef")

    private let salt: String
    private let identifierResolver: @MainActor () -> String

    init(
        salt: String,
        identifierResolver: @escaping @MainActor () -> String = Self.systemIdentifier
    ) {
        self.salt = salt
        self.identifierResolver = identifierResolver
    }

    func deviceHash() -> String {
        let identifier = identifierResolver()
        let combined = identifier + salt
        guard let data = combined.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.reduce(into: "") { result, byte in
            let value = Int(byte)
            result.append(Self.hexCharacters[(value >> 4) & 0x0F])
            result.append(Self.hexCharacters[value & 0x0F])
        }
    }

    private static func systemIdentifier() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
}
