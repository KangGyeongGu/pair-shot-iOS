import Foundation

protocol FileNameBuilding: Sendable {
    func before(prefix: String, timestamp: Date, pairId: UUID) -> String
    func after(prefix: String, timestamp: Date, pairId: UUID) -> String
    func combined(prefix: String, timestamp: Date, pairId: UUID) -> String
}
