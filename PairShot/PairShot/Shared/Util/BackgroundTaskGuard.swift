import Foundation
import UIKit

@MainActor
final class BackgroundTaskGuard {
    private var activeTasks: [UUID: UIBackgroundTaskIdentifier] = [:]

    init() {}

    @discardableResult
    func run<T>(_ name: String, _ work: @MainActor () async throws -> T) async rethrows -> T {
        let id = UUID()
        let identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.expire(id: id)
        }
        if identifier != .invalid {
            activeTasks[id] = identifier
        }
        defer { end(id: id) }
        return try await work()
    }

    private func end(id: UUID) {
        guard let identifier = activeTasks.removeValue(forKey: id), identifier != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(identifier)
    }

    private func expire(id: UUID) {
        end(id: id)
    }

    deinit {}
}
