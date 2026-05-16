import Foundation
@testable import PairShot
import Testing

@MainActor
struct TutorialPersistenceTests {
    private static let key = "tutorial.completed"

    @Test
    func `restart 은 nil 상태에서 첫 step 으로 복귀`() {
        let coord = TutorialCoordinator()
        coord.restart()
        #expect(coord.current == .homeCaptureHighlight)
        #expect(coord.isActive == true)
    }

    @Test
    func `restart 은 중간 step 에서도 첫 step 으로 되돌린다`() {
        let coord = TutorialCoordinator(current: .tapPairCard)
        coord.restart()
        #expect(coord.current == .homeCaptureHighlight)
    }

    @Test
    func `restart 은 done 상태에서도 첫 step 으로 되돌린다`() {
        let coord = TutorialCoordinator()
        coord.complete()
        #expect(coord.current == .done)
        coord.restart()
        #expect(coord.current == .homeCaptureHighlight)
    }

    @Test
    func `complete 호출은 current 를 done 으로 만든다`() {
        let coord = TutorialCoordinator()
        coord.start()
        coord.complete()
        #expect(coord.current == .done)
    }

    @Test
    func `tutorialCompleted UserDefaults 기본값은 false`() throws {
        let defaults = try #require(UserDefaults(suiteName: "tutorial-persistence-default-\(UUID().uuidString)"))
        defer { defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description) }
        let value = defaults.bool(forKey: Self.key)
        #expect(value == false)
    }

    @Test
    func `tutorialCompleted true 저장 후 읽기 일치`() throws {
        let suite = "tutorial-persistence-true-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(true, forKey: Self.key)
        #expect(defaults.bool(forKey: Self.key) == true)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test
    func `tutorialCompleted false 인 사용자 시작 게이트 시뮬레이션`() throws {
        let suite = "tutorial-persistence-firstrun-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let completed = defaults.bool(forKey: Self.key)
        let coord = TutorialCoordinator()
        if !completed, !coord.isActive { coord.start() }
        #expect(coord.current == .homeCaptureHighlight)
    }

    @Test
    func `tutorialCompleted true 인 사용자 시작 게이트 시뮬레이션`() throws {
        let suite = "tutorial-persistence-existing-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: Self.key)
        let completed = defaults.bool(forKey: Self.key)
        let coord = TutorialCoordinator()
        if !completed, !coord.isActive { coord.start() }
        #expect(coord.current == nil)
        #expect(coord.isActive == false)
    }

    @Test
    func `이미 활성 상태면 재시작 게이트 시뮬레이션은 중복 호출 안 함`() {
        let coord = TutorialCoordinator(current: .tapPairCard)
        let completed = false
        if !completed, !coord.isActive { coord.start() }
        #expect(coord.current == .tapPairCard)
    }
}
