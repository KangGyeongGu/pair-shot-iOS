import Foundation

protocol AsyncSleeper: Sendable {
    func sleep(seconds: TimeInterval) async throws
}

struct SystemSleeper: AsyncSleeper {
    func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
