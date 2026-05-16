import Foundation
@testable import PairShot
import Testing

struct ExportProgressCounterTests {
    @Test
    func `tick increments fraction monotonically up to 1`() async {
        let storage = ProgressStorage()
        let counter = ExportProgressCounter(total: 10) { fraction, done, total in
            storage.append(fraction: fraction, done: done, total: total)
        }
        for _ in 0 ..< 10 {
            await counter.tick()
        }
        let observed = storage.snapshot()
        #expect(observed.count == 10)
        #expect(observed.last?.fraction == 1.0)
        #expect(observed.last?.done == 10)
        #expect(observed.last?.total == 10)
        for index in 1 ..< observed.count {
            #expect(observed[index].fraction >= observed[index - 1].fraction)
            #expect(observed[index].done == index + 1)
            #expect(observed[index].total == 10)
        }
    }

    @Test
    func `concurrent ticks remain race-free under actor isolation`() async {
        let storage = ProgressStorage()
        let counter = ExportProgressCounter(total: 100) { fraction, done, total in
            storage.append(fraction: fraction, done: done, total: total)
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
        let snapshot = storage.snapshot()
        #expect(snapshot.count == 100)
        #expect(snapshot.last?.done == 100)
        #expect(snapshot.last?.total == 100)
    }

    @Test
    func `total zero degrades safely`() async {
        let counter = ExportProgressCounter(total: 0) { _, _, _ in }
        await counter.tick()
        let final = await counter.currentFraction()
        #expect(final == 1.0)
    }
}

private struct ProgressSample {
    let fraction: Double
    let done: Int
    let total: Int
}

private final class ProgressStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ProgressSample] = []

    func append(fraction: Double, done: Int, total: Int) {
        lock.lock()
        defer { lock.unlock() }
        values.append(ProgressSample(fraction: fraction, done: done, total: total))
    }

    func snapshot() -> [ProgressSample] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
