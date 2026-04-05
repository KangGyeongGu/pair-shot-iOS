import UIKit

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private nonisolated(unsafe) var store: [String: UIImage] = [:]
    private nonisolated(unsafe) var order: [String] = []
    private let lock = NSLock()
    private let maxCount = 200

    private init() {}

    func image(for path: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = store[path] {
            return cached
        }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        insertLocked(image, for: path)
        return image
    }

    nonisolated func imageAsync(for path: String) async -> UIImage? {
        if let cached = lockedGet(path) { return cached }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        let prepared = await image.byPreparingForDisplay() ?? image
        lockedSet(path, prepared)
        return prepared
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
        order.removeAll()
    }

    private nonisolated func lockedGet(_ path: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return store[path]
    }

    private nonisolated func lockedSet(_ path: String, _ image: UIImage) {
        lock.lock()
        defer { lock.unlock() }
        insertLocked(image, for: path)
    }

    private nonisolated func insertLocked(_ image: UIImage, for path: String) {
        if store[path] == nil {
            order.append(path)
        }
        store[path] = image
        if order.count > maxCount {
            let evicted = order.removeFirst()
            store.removeValue(forKey: evicted)
        }
    }
}
