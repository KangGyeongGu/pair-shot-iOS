import Foundation
@testable import PairShot
import Testing

@MainActor
struct SnackbarQueueAPITests {
    @Test
    func `enqueue 시 current 의 title body iconSymbol variant 가 Resolver 결과와 일치`() {
        let queue = SnackbarQueue()

        queue.enqueue(.savedToPhotos)

        let resolution = SnackbarReasonResolver.resolve(.savedToPhotos)
        let current = queue.current
        #expect(current != nil)
        #expect(current?.title == resolution.title)
        #expect(current?.body == resolution.body)
        #expect(current?.iconSymbol == resolution.iconSymbol)
        if case .success = current?.variant {
        } else {
            Issue.record("expected .success, got \(String(describing: current?.variant))")
        }
    }

    @Test
    func `같은 reason 1초 안에 두 번 enqueue 시 두 번째는 debounce 차단`() {
        var now = Date(timeIntervalSince1970: 1_000)
        let queue = SnackbarQueue(clock: { now })

        queue.enqueue(.shareFailed)
        let firstId = queue.current?.id
        queue.dismiss()
        #expect(queue.current == nil)

        now = now.addingTimeInterval(0.5)
        queue.enqueue(.shareFailed)
        #expect(queue.current == nil, "0.5초 안에 같은 reason 재호출은 차단되어야 함")

        now = now.addingTimeInterval(1.0)
        queue.enqueue(.shareFailed)
        #expect(queue.current != nil)
        #expect(queue.current?.id != firstId)
    }

    @Test
    func `다른 debounceKey 명시 시 같은 reason 도 즉시 다시 enqueue 가능`() {
        var now = Date(timeIntervalSince1970: 1_000)
        let queue = SnackbarQueue(clock: { now })

        queue.enqueue(.shareFailed, debounceKey: "k1")
        queue.dismiss()

        now = now.addingTimeInterval(0.1)
        queue.enqueue(.shareFailed, debounceKey: "k2")

        #expect(queue.current != nil, "다른 키면 차단 안 됨")
    }

    @Test
    func `enqueueProgress → updateProgress → completeProgress finalReason 흐름`() {
        let queue = SnackbarQueue()

        let handle = queue.enqueueProgress(.prepareZipExport, token: "tok1", initialValue: 0)
        #expect(queue.current?.token == "tok1")
        if case let .progress(value, _, _) = queue.current?.variant {
            #expect(value == 0)
        } else {
            Issue.record("expected .progress variant")
        }

        queue.updateProgress(handle, value: 0.5, processed: 5, total: 10)
        if case let .progress(value, processed, total) = queue.current?.variant {
            #expect(value == 0.5)
            #expect(processed == 5)
            #expect(total == 10)
        } else {
            Issue.record("expected .progress with updated value")
        }
        #expect(queue.current?.token == "tok1", "token 유지")

        queue.completeProgress(handle, finalReason: .savedZip)
        let savedResolution = SnackbarReasonResolver.resolve(.savedZip)
        #expect(queue.current?.title == savedResolution.title)
        #expect(queue.current?.body == savedResolution.body)
        #expect(queue.current?.token == nil, "replacement 는 token 없음")
    }

    @Test
    func `cancelProgress 는 completeProgress finalReason nil 과 동등`() {
        let queueA = SnackbarQueue()
        let handleA = queueA.enqueueProgress(.share, token: "t", initialValue: 0)
        queueA.cancelProgress(handleA)
        #expect(queueA.current == nil)

        let queueB = SnackbarQueue()
        let handleB = queueB.enqueueProgress(.share, token: "t", initialValue: 0)
        queueB.completeProgress(handleB, finalReason: nil)
        #expect(queueB.current == nil)
    }

    @Test
    func `progress 변형은 자동 dismiss 없이 명시 호출까지 current 유지`() async {
        let queue = SnackbarQueue()

        _ = queue.enqueueProgress(.saveToPhotos, token: "t", initialValue: 0)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(queue.current != nil, "progress 는 자동 dismiss 되지 않음")
        #expect(queue.current?.token == "t")
    }
}
