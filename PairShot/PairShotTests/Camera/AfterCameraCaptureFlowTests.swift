@preconcurrency import AVFoundation
import Foundation
@testable import PairShot
import SwiftData
import Testing
import UniformTypeIdentifiers

@MainActor
struct AfterCameraCaptureFlowTests {
    @Test
    func `shutter — currentPair 가 nil 이면 즉시 return`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready

        await viewModel.shutter()

        #expect(viewModel.isCapturing == false)
        #expect(viewModel.captureErrorMessage == nil)
    }

    @Test
    func `shutter — isCapturing=true 이면 즉시 return`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready
        viewModel.currentPair = FixturePhotoPair.makeBeforeOnly()
        viewModel.isCapturing = true

        await viewModel.shutter()

        #expect(viewModel.isCapturing == true)
        #expect(viewModel.captureErrorMessage == nil)
    }

    @Test
    func `shutter — captureReadiness 가 ready 아니면 즉시 return`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        viewModel.currentPair = FixturePhotoPair.makeBeforeOnly()

        await viewModel.shutter()

        #expect(viewModel.isCapturing == false)
        #expect(viewModel.captureErrorMessage == nil)
    }

    @Test
    func `shutter — capturePhoto 실패 시 captureErrorMessage 세팅 + isCapturing false 복귀`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready
        viewModel.currentPair = FixturePhotoPair.makeBeforeOnly()

        await viewModel.shutter()

        #expect(viewModel.captureErrorMessage != nil)
        #expect(viewModel.isCapturing == false)
    }

    @Test
    func `contractPairsAndAdvance — non-recapture 일반 흐름은 다음 페어로 advance`() {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let pairA = FixturePhotoPair.makeBeforeOnly()
        let pairB = FixturePhotoPair.makeBeforeOnly()
        viewModel.pairs = [pairA, pairB]
        viewModel.currentPair = pairA
        viewModel.pendingPairCount = 2
        viewModel.completedPairCount = 0

        viewModel.contractPairsAndAdvance(removing: pairA.id)

        #expect(viewModel.pairs.count == 1)
        #expect(viewModel.pairs.first?.id == pairB.id)
        #expect(viewModel.currentPair?.id == pairB.id)
        #expect(viewModel.pendingPairCount == 1)
        #expect(viewModel.completedPairCount == 1)
        #expect(viewModel.allCompleted == false)
    }

    @Test
    func `contractPairsAndAdvance — capturedIndex 보다 뒤의 페어가 남으면 같은 index 로 adopt`() {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let pairA = FixturePhotoPair.makeBeforeOnly()
        let pairB = FixturePhotoPair.makeBeforeOnly()
        let pairC = FixturePhotoPair.makeBeforeOnly()
        viewModel.pairs = [pairA, pairB, pairC]
        viewModel.currentPair = pairB
        viewModel.pendingPairCount = 3

        viewModel.contractPairsAndAdvance(removing: pairB.id)

        #expect(viewModel.pairs.map(\.id) == [pairA.id, pairC.id])
        #expect(viewModel.currentPair?.id == pairC.id)
        #expect(viewModel.pendingPairCount == 2)
    }

    @Test
    func `contractPairsAndAdvance — 마지막 페어 캡처 시 allCompleted=true + snackbarAllCompleted 이벤트`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let pair = FixturePhotoPair.makeBeforeOnly()
        viewModel.pairs = [pair]
        viewModel.currentPair = pair
        viewModel.pendingPairCount = 1
        var iterator = viewModel.events.makeAsyncIterator()

        viewModel.contractPairsAndAdvance(removing: pair.id)

        #expect(viewModel.pairs.isEmpty)
        #expect(viewModel.allCompleted == true)
        #expect(viewModel.currentPair == nil)
        #expect(viewModel.ghostImageData == nil)
        let event = await iterator.next()
        if case .snackbarAllCompleted = event {} else {
            Issue.record("expected snackbarAllCompleted, got \(String(describing: event))")
        }
        viewModel.allCompletedDismissTask?.cancel()
    }

    @Test
    func `contractPairsAndAdvance — isRecaptureMode 면 즉시 dismiss 이벤트 + allCompleted=true`() async {
        let env = Self.makeEnv()
        let target = FixturePhotoPair.make()
        let viewModel = env.makeAfterCameraViewModel(
            albumId: nil,
            recaptureTargetPair: target,
        )
        viewModel.pairs = [target]
        viewModel.currentPair = target
        var iterator = viewModel.events.makeAsyncIterator()

        viewModel.contractPairsAndAdvance(removing: target.id)

        #expect(viewModel.allCompleted == true)
        #expect(viewModel.currentPair == nil)
        let event = await iterator.next()
        if case .dismiss = event {} else {
            Issue.record("expected dismiss, got \(String(describing: event))")
        }
    }

    @Test
    func `persistAfter — non-recapture 모드는 captureAfter 호출 + pair 의 afterPhotoLocalIdentifier 갱신`() async throws {
        let env = Self.makeEnv()
        let tutorialPair = FixturePhotoPair.makeBeforeOnly(isTutorial: true)
        try await env.pairRepo.add(tutorialPair)
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)
        let data = Self.tinyImageData()

        let updated = try await viewModel.persistAfter(
            pairId: tutorialPair.id,
            afterData: data,
            afterUTType: .jpeg,
            aspectRatio: .default,
            isDeferredProxy: false,
        )

        #expect(updated.afterPhotoLocalIdentifier != nil)
        #expect(updated.afterPhotoLocalIdentifier?.hasPrefix(TutorialPhotoStore.identifierPrefix) == true)
        let refetched = try await env.pairRepo.fetch(id: tutorialPair.id)
        #expect(refetched?.afterPhotoLocalIdentifier != nil)
    }

    @Test
    func `persistAfter — recapture 모드는 recaptureAfter 호출 + afterPhotoLocalIdentifier 갱신`() async throws {
        let env = Self.makeEnv()
        let existingTutorialAfter = TutorialPhotoStore.identifierPrefix + "stale-\(UUID().uuidString).jpg"
        let target = FixturePhotoPair.make(
            beforePhotoLocalIdentifier: TutorialPhotoStore.identifierPrefix + "before.jpg",
            afterPhotoLocalIdentifier: existingTutorialAfter,
            isTutorial: true,
        )
        try await env.pairRepo.add(target)
        let viewModel = env.makeAfterCameraViewModel(
            albumId: nil,
            recaptureTargetPair: target,
        )
        let data = Self.tinyImageData()

        let updated = try await viewModel.persistAfter(
            pairId: target.id,
            afterData: data,
            afterUTType: .jpeg,
            aspectRatio: .default,
            isDeferredProxy: false,
        )

        #expect(updated.afterPhotoLocalIdentifier != nil)
        #expect(updated.afterPhotoLocalIdentifier != existingTutorialAfter)
        #expect(updated.afterPhotoLocalIdentifier?.hasPrefix(TutorialPhotoStore.identifierPrefix) == true)
    }

    @Test
    func `persistAfter — pair 가 존재하지 않으면 pairNotFound throw`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)

        await #expect(throws: CaptureAfterUseCase.CaptureAfterError.pairNotFound) {
            _ = try await viewModel.persistAfter(
                pairId: UUID(),
                afterData: Self.tinyImageData(),
                afterUTType: .jpeg,
                aspectRatio: .default,
                isDeferredProxy: false,
            )
        }
    }

    @Test
    func `advanceTutorialOnAllCompleted — afterCameraGuide 단계면 한 단계 advance`() {
        let env = Self.makeEnv()
        env.tutorialCoordinator.start()
        while env.tutorialCoordinator.current != .afterCameraGuide,
              env.tutorialCoordinator.current != .done
        {
            env.tutorialCoordinator.advance()
        }
        #expect(env.tutorialCoordinator.current == .afterCameraGuide)
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)

        viewModel.advanceTutorialOnAllCompleted()

        #expect(env.tutorialCoordinator.current != .afterCameraGuide)
    }

    @Test
    func `advanceTutorialOnAllCompleted — 무관한 단계면 advance 안 함`() {
        let env = Self.makeEnv()
        env.tutorialCoordinator.start()
        let initialStep = env.tutorialCoordinator.current
        let viewModel = env.makeAfterCameraViewModel(albumId: nil)

        viewModel.advanceTutorialOnAllCompleted()

        #expect(env.tutorialCoordinator.current == initialStep)
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "after-capture-flow-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let settings = AppSettings(defaults: defaults)
        return AppEnvironment(
            modelContainer: makeContainer(),
            appSettings: settings,
        )
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("test container failure: \(error)")
        }
    }

    private static func tinyImageData() -> Data {
        Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
    }
}
