import Foundation

actor ExportProgressCounter {
    private var done = 0
    private let total: Int
    private let onUpdate: @Sendable (Double) -> Void

    init(total: Int, onUpdate: @escaping @Sendable (Double) -> Void) {
        self.total = total
        self.onUpdate = onUpdate
    }

    func tick() {
        done += 1
        let fraction = Double(done) / Double(max(total, 1))
        onUpdate(fraction)
    }

    func currentFraction() -> Double {
        Double(done) / Double(max(total, 1))
    }
}
