import Foundation
@testable import PairShot
import SwiftUI
import XCTest

/// Audit-B — `CameraScenePhaseGate.action(for:)` is the pure decision
/// `BeforeCameraView` / `AfterCameraView` consult on every
/// `.onChange(of: scenePhase)` event. The view-side wrapper hands the
/// returned action to the `CameraSession` actor (`.start` /
/// `.stop`) and skips on `nil` (`.inactive`, `@unknown default`).
///
/// These tests pin the policy:
/// - `.background` ⇒ `.stop` (release the camera; battery / privacy).
/// - `.active`     ⇒ `.start` (foreground re-entry restores preview).
/// - `.inactive`   ⇒ `nil` (transient interruption — keep session up
///                  so the user returns to a live preview without a
///                  perceivable hiccup).
final class CameraScenePhaseTests: XCTestCase {
    // MARK: - happy

    func testBackgroundProducesStopAction() {
        XCTAssertEqual(CameraScenePhaseGate.action(for: .background), .stop)
    }

    func testActiveProducesStartAction() {
        XCTAssertEqual(CameraScenePhaseGate.action(for: .active), .start)
    }

    // MARK: - edge

    func testInactiveProducesNoAction() {
        XCTAssertNil(
            CameraScenePhaseGate.action(for: .inactive),
            ".inactive must NOT tear the session down — transient phone-call / control-centre interruption"
        )
    }

    // MARK: - integration: protocol-fake CameraSession action sequence

    /// Simulates a full `.background → .active` round-trip and asserts
    /// the corresponding action sequence the view-side wrapper would
    /// dispatch to `CameraSession`.
    func testBackgroundThenActiveSequenceMapsToStopThenStart() {
        let sequence: [ScenePhase] = [.background, .active]
        let actions = sequence.compactMap(CameraScenePhaseGate.action(for:))
        XCTAssertEqual(actions, [.stop, .start])
    }

    /// Simulates a `.inactive → .active` transient round-trip and
    /// asserts the wrapper dispatches a single `.start` (the
    /// `.inactive` produces no action).
    func testInactiveThenActiveSequenceProducesOnlyStart() {
        let sequence: [ScenePhase] = [.inactive, .active]
        let actions = sequence.compactMap(CameraScenePhaseGate.action(for:))
        XCTAssertEqual(actions, [.start])
    }

    /// Counts call-site invocations under a real-world phase walk:
    /// `.active → .inactive → .background → .active`. Mirrors what
    /// happens when the user (a) launches the app, (b) gets a phone
    /// call (active→inactive), (c) the call drops the app to
    /// background, (d) the user returns. The wrapper should dispatch
    /// exactly one `.stop` (on `.background`) and one `.start` (on
    /// the final `.active`).
    func testRealisticLifecycleCountsOneStopAndOneStart() {
        let sequence: [ScenePhase] = [.active, .inactive, .background, .active]
        let actions = sequence.compactMap(CameraScenePhaseGate.action(for:))
        XCTAssertEqual(actions.count(where: { $0 == .stop }), 1)
        XCTAssertEqual(actions.count(where: { $0 == .start }), 2)
    }
}
