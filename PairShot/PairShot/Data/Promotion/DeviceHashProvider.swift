import CryptoKit
import Foundation

nonisolated struct DeviceHashProvider {
    private static let hexCharacters: [Character] = Array("0123456789abcdef")

    private let identifierResolver: () -> String

    init(identifierResolver: @escaping () -> String = KeychainDeviceUUID.loadOrCreate) {
        self.identifierResolver = identifierResolver
    }

    func deviceHash() -> String {
        let identifier = identifierResolver()
        guard let data = identifier.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.reduce(into: "") { result, byte in
            let value = Int(byte)
            result.append(Self.hexCharacters[(value >> 4) & 0x0F])
            result.append(Self.hexCharacters[value & 0x0F])
        }
    }
}
