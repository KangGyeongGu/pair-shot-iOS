actor ExportProgressCounter {
    private var done = 0
    private let total: Int
    private let onUpdate: @Sendable (_ fraction: Double, _ done: Int, _ total: Int) -> Void

    init(
        total: Int,
        onUpdate: @escaping @Sendable (_ fraction: Double, _ done: Int, _ total: Int) -> Void,
    ) {
        self.total = total
        self.onUpdate = onUpdate
    }

    func tick() {
        done += 1
        let fraction = Double(done) / Double(max(total, 1))
        onUpdate(fraction, done, total)
    }

    func currentFraction() -> Double {
        Double(done) / Double(max(total, 1))
    }
}
