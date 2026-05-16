import Foundation
@testable import PairShot
import Testing

struct ExportSlidingWindowTests {
    @Test
    func `empty jobs returns empty results without invoking transform`() async throws {
        let invocationCounter = InvocationCounter()
        let result: [Int] = try await ExportSlidingWindow.map(
            jobs: [Int](),
            cap: 3,
        ) { _, job in
            invocationCounter.bump()
            return job
        }
        #expect(result.isEmpty)
        #expect(invocationCounter.value() == 0)
    }

    @Test
    func `random delay renders preserve input order`() async throws {
        let inputs = Array(0 ..< 30)
        let result: [Int] = try await ExportSlidingWindow.map(
            jobs: inputs,
            cap: 3,
        ) { _, job in
            let nanoseconds = UInt64.random(in: 1000 ... 5_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
            return job * 2
        }
        #expect(result == inputs.map { $0 * 2 })
    }

    @Test
    func `cap greater than total clamps safely`() async throws {
        let inputs = Array(0 ..< 5)
        let result: [Int] = try await ExportSlidingWindow.map(
            jobs: inputs,
            cap: 100,
        ) { _, job in
            job + 100
        }
        #expect(result == inputs.map { $0 + 100 })
    }

    @Test
    func `first throwing transform propagates error and cancels group`() async {
        let inputs = Array(0 ..< 10)
        let invocationCounter = InvocationCounter()
        do {
            _ = try await ExportSlidingWindow.map(
                jobs: inputs,
                cap: 3,
            ) { _, job in
                invocationCounter.bump()
                if job == 5 {
                    throw IntentionalFailure()
                }
                try await Task.sleep(nanoseconds: 100_000)
                return job
            }
            Issue.record("Expected throw to propagate")
        } catch is IntentionalFailure {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(invocationCounter.value() <= inputs.count)
    }

    @Test
    func `external cancellation throws CancellationError`() async {
        let inputs = Array(0 ..< 20)
        let task = Task<[Int], Error> {
            try await ExportSlidingWindow.map(
                jobs: inputs,
                cap: 2,
            ) { _, job in
                try await Task.sleep(nanoseconds: 10_000_000)
                return job
            }
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected CancellationError after task.cancel()")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `onItemComplete fires once per finished item in order finished`() async throws {
        let inputs = Array(0 ..< 10)
        let counter = TickCounter()
        let result = try await ExportSlidingWindow.map(
            jobs: inputs,
            cap: 3,
            onItemComplete: { await counter.tick() },
            transform: { _, job in
                try await Task.sleep(nanoseconds: UInt64.random(in: 1000 ... 1_000_000))
                return job
            },
        )
        let ticks = await counter.count
        #expect(ticks == inputs.count)
        #expect(result == inputs)
    }
}

private struct IntentionalFailure: Error {}

private final class InvocationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counter = 0

    func bump() {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
    }

    func value() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counter
    }
}

private actor TickCounter {
    private(set) var count = 0
    func tick() {
        count += 1
    }
}
