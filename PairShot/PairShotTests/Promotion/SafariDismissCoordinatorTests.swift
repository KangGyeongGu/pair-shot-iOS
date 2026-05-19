import Foundation
@testable import PairShot
import SafariServices
import Testing

struct SafariDismissCoordinatorTests {
    @Test
    @MainActor
    func `safariViewControllerDidFinish 호출 시 onFinish 콜백 1회 실행`() throws {
        var callCount = 0
        let coordinator = SafariDismissCoordinator { callCount += 1 }
        let url = try #require(URL(string: "https://example.com"))
        let fakeSafari = SFSafariViewController(url: url)

        coordinator.safariViewControllerDidFinish(fakeSafari)

        #expect(callCount == 1)
    }

    @Test
    @MainActor
    func `cleanup 콜백이 onFinish 후 순서대로 호출`() throws {
        var sequence: [String] = []
        let coordinator = SafariDismissCoordinator { sequence.append("onFinish") }
        coordinator.cleanup = { sequence.append("cleanup") }
        let url = try #require(URL(string: "https://example.com"))
        let fakeSafari = SFSafariViewController(url: url)

        coordinator.safariViewControllerDidFinish(fakeSafari)

        #expect(sequence == ["onFinish", "cleanup"])
    }

    @Test
    @MainActor
    func `cleanup 가 nil 이면 onFinish 만 실행되고 crash 없음`() throws {
        var onFinishCount = 0
        let coordinator = SafariDismissCoordinator { onFinishCount += 1 }
        let url = try #require(URL(string: "https://example.com"))
        let fakeSafari = SFSafariViewController(url: url)

        coordinator.safariViewControllerDidFinish(fakeSafari)

        #expect(onFinishCount == 1)
    }

    @Test
    @MainActor
    func `delegate method 가 여러 번 호출되면 onFinish 도 매번 호출`() throws {
        var callCount = 0
        let coordinator = SafariDismissCoordinator { callCount += 1 }
        let url = try #require(URL(string: "https://example.com"))
        let fakeSafari = SFSafariViewController(url: url)

        coordinator.safariViewControllerDidFinish(fakeSafari)
        coordinator.safariViewControllerDidFinish(fakeSafari)
        coordinator.safariViewControllerDidFinish(fakeSafari)

        #expect(callCount == 3)
    }

    @Test
    @MainActor
    func `여러 cleanup 호출 시 array_removeAll 패턴 시뮬레이션 — closure 매번 실행`() throws {
        var registry: [String] = ["a", "b", "c"]
        let coordinator = SafariDismissCoordinator {}
        coordinator.cleanup = { registry.removeAll { $0 == "b" } }
        let url = try #require(URL(string: "https://example.com"))
        let fakeSafari = SFSafariViewController(url: url)

        coordinator.safariViewControllerDidFinish(fakeSafari)

        #expect(registry == ["a", "c"])
    }

    @Test
    @MainActor
    func `독립된 coordinator 두 instance 의 onFinish 는 서로 격리`() throws {
        var firstCount = 0
        var secondCount = 0
        let first = SafariDismissCoordinator { firstCount += 1 }
        let second = SafariDismissCoordinator { secondCount += 1 }
        let url = try #require(URL(string: "https://example.com"))
        let fakeSafari = SFSafariViewController(url: url)

        first.safariViewControllerDidFinish(fakeSafari)

        #expect(firstCount == 1)
        #expect(secondCount == 0)

        second.safariViewControllerDidFinish(fakeSafari)

        #expect(firstCount == 1)
        #expect(secondCount == 1)
    }

    @Test
    @MainActor
    func `weak coordinator capture 시 strong reference 가 살아있는 동안 cleanup 정상 동작`() throws {
        var cleanupExecuted = false
        var coordinator: SafariDismissCoordinator? = SafariDismissCoordinator {}
        coordinator?.cleanup = { [weak coordinator] in
            guard coordinator != nil else { return }
            cleanupExecuted = true
        }
        let url = try #require(URL(string: "https://example.com"))
        let fakeSafari = SFSafariViewController(url: url)

        coordinator?.safariViewControllerDidFinish(fakeSafari)

        #expect(cleanupExecuted)

        coordinator = nil
        #expect(coordinator == nil)
    }
}
