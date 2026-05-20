@preconcurrency import AVFoundation
import Foundation
@testable import PairShot
import SwiftData
import Testing

@MainActor
struct BeforeCameraCaptureFlowTests {
    @Test
    func `shutter — captureReadiness 가 sessionNotRunning 이면 즉시 return (capture 미시도)`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)

        await viewModel.shutter(rollDegrees: 0)

        #expect(viewModel.isCapturing == false)
        #expect(viewModel.captureErrorMessage == nil)
        #expect(viewModel.showPaywall == false)
        let createdToday = await (try? env.pairRepo.countCreated(since: .distantPast)) ?? 0
        #expect(createdToday == 0)
    }

    @Test
    func `shutter — isCapturing=true 이면 readiness 무관하게 즉시 return`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready
        viewModel.isCapturing = true

        await viewModel.shutter(rollDegrees: 0)

        #expect(viewModel.isCapturing == true)
        #expect(viewModel.captureErrorMessage == nil)
        #expect(viewModel.showPaywall == false)
    }

    @Test
    func `shutter — capturePhoto 실패 시 captureErrorMessage 세팅 + isCapturing false 복귀`() async {
        let env = Self.makeEnv()
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready

        await viewModel.shutter(rollDegrees: 0)

        #expect(viewModel.captureErrorMessage != nil)
        #expect(viewModel.isCapturing == false)
        #expect(viewModel.showPaywall == false)
    }

    @Test
    func `shutter — 무료 사용자 + 일일 5건 초과 시 showPaywall=true + capture 미시도`() async throws {
        let env = Self.makeEnv()
        let today = Date()
        for _ in 0 ..< PairLimitGate.freeTierDailyLimit {
            try await env.pairRepo.add(FixturePhotoPair.make(createdAt: today))
        }
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready

        await viewModel.shutter(rollDegrees: 0)

        #expect(viewModel.showPaywall == true)
        #expect(viewModel.captureErrorMessage == nil)
        #expect(viewModel.isCapturing == false)
    }

    @Test
    func `shutter — refillPairId 존재하면 일일 한도 초과여도 게이트 우회 (capture 시도)`() async throws {
        let env = Self.makeEnv()
        let today = Date()
        for _ in 0 ..< PairLimitGate.freeTierDailyLimit {
            try await env.pairRepo.add(FixturePhotoPair.make(createdAt: today))
        }
        let refillTarget = FixturePhotoPair.makeBeforeOnly()
        try await env.pairRepo.add(refillTarget)
        let viewModel = env.makeBeforeCameraViewModel(
            albumId: nil,
            refillPairId: refillTarget.id,
        )
        viewModel.session.captureReadiness = .ready

        await viewModel.shutter(rollDegrees: 0)

        #expect(viewModel.showPaywall == false)
        #expect(viewModel.captureErrorMessage != nil)
    }

    @Test
    func `shutter — tutorial 활성 + posture 불일치면 advance 안 함 + capture 시도 안 함`() async {
        let env = Self.makeEnv()
        env.tutorialCoordinator.start()
        let initialStep = env.tutorialCoordinator.current
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready

        await viewModel.shutter(rollDegrees: 50)

        #expect(env.tutorialCoordinator.current == initialStep)
        #expect(viewModel.captureErrorMessage == nil)
        #expect(viewModel.isCapturing == false)
    }

    @Test
    func `shutter — tutorial 활성 + posture 일치면 advance + capture 시도 (실패 시 errorMessage)`() async {
        let env = Self.makeEnv()
        env.tutorialCoordinator.start()
        let initialStep = env.tutorialCoordinator.current
        let viewModel = env.makeBeforeCameraViewModel(albumId: nil)
        viewModel.session.captureReadiness = .ready

        await viewModel.shutter(rollDegrees: 0)

        #expect(env.tutorialCoordinator.current != initialStep)
        #expect(viewModel.captureErrorMessage != nil)
        #expect(viewModel.isCapturing == false)
    }

    private static func makeEnv() -> AppEnvironment {
        let suiteName = "before-capture-flow-\(UUID().uuidString)"
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
}
