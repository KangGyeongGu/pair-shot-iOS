import UIKit

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private var store: [String: UIImage] = [:]
    private var order: [String] = []
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
        insert(image, for: path)
        return image
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
        order.removeAll()
    }

    private func insert(_ image: UIImage, for path: String) {
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
