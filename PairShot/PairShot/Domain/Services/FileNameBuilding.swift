import Foundation

protocol FileNameBuilding: Sendable {
    func before(prefix: String, timestamp: Date, sequenceNumber: Int) -> String
    func after(prefix: String, timestamp: Date, sequenceNumber: Int) -> String
    func combined(prefix: String, timestamp: Date, sequenceNumber: Int) -> String
}
