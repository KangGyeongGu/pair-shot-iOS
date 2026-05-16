import Foundation
@testable import PairShot
import Testing

struct ExportProgressCounterTests {
    @Test
    func `tick increments fraction monotonically up to 1`() async {
        let storage = FractionStorage()
        let counter = ExportProgressCounter(total: 10) { fraction in
            storage.append(fraction)
        }
        for _ in 0 ..< 10 {
            await counter.tick()
        }
        let observed = storage.snapshot()
        #expect(observed.count == 10)
        #expect(observed.last == 1.0)
        for index in 1 ..< observed.count {
            #expect(observed[index] >= observed[index - 1])
        }
    }

    @Test
    func `concurrent ticks remain race-free under actor isolation`() async {
        let storage = FractionStorage()
        let counter = ExportProgressCounter(total: 100) { fraction in
            storage.append(fraction)
        }
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    await counter.tick()
                }
            }
        }
        let final = await counter.currentFraction()
        #expect(final == 1.0)
        #expect(storage.snapshot().count == 100)
    }

    @Test
    func `total zero degrades safely`() async {
        let counter = ExportProgressCounter(total: 0) { _ in }
        await counter.tick()
        let final = await counter.currentFraction()
        #expect(final == 1.0)
    }
}

private final class FractionStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []

    func append(_ value: Double) {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
    }

    func snapshot() -> [Double] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
