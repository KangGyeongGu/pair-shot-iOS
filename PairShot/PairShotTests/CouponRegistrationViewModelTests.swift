import Foundation
@testable import PairShot
import SwiftData
import XCTest

/// P6.4 — `CouponRegistrationViewModel` orchestrates parse → verify →
/// persist → refresh, with all dependencies injectable.
@MainActor
final class CouponRegistrationViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    private var store: AdFreeStore!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, PhotoPair.self, Coupon.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        store = AdFreeStore(context: container.mainContext)
    }

    override func tearDownWithError() throws {
        store = nil
        container = nil
    }

    // MARK: - happy

    func testValidTokenRegistersAndActivatesAdFree() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = CouponRegistrationViewModel()
        viewModel.inputToken = "GOLDEN-CODE.dGVzdA=="

        await viewModel.submit(
            verifier: { _, _ in true },
            store: store,
            context: context,
            durationDays: 30,
            now: now
        )

        XCTAssertNil(viewModel.lastError)
        XCTAssertNotNil(viewModel.lastSuccessExpiration)
        XCTAssertTrue(store.isAdFree)

        let coupons = try context.fetch(FetchDescriptor<Coupon>())
        XCTAssertEqual(coupons.count, 1)
        XCTAssertEqual(coupons.first?.code, "GOLDEN-CODE")
        XCTAssertEqual(coupons.first?.signatureBase64, "dGVzdA==")
        XCTAssertEqual(coupons.first?.activatedAt, now)
        XCTAssertEqual(coupons.first?.durationDays, 30)
    }

    func testAcceptScannedTokenSetsInputAndSubmits() async {
        let viewModel = CouponRegistrationViewModel()
        await viewModel.acceptScannedToken(
            "SCAN-CODE.QQ==",
            verifier: { _, _ in true },
            store: store,
            context: context
        )

        XCTAssertEqual(viewModel.inputToken, "SCAN-CODE.QQ==")
        XCTAssertNil(viewModel.lastError)
        XCTAssertNotNil(viewModel.lastSuccessExpiration)
        XCTAssertTrue(store.isAdFree)
    }

    // MARK: - validation / parser failures

    func testEmptyInputProducesInvalidFormat() async {
        let viewModel = CouponRegistrationViewModel()
        viewModel.inputToken = ""
        await viewModel.submit(
            verifier: { _, _ in
                XCTFail("verifier should not be called on empty input")
                return false
            },
            store: store,
            context: context
        )
        XCTAssertEqual(viewModel.lastError, .invalidFormat)
        XCTAssertNil(viewModel.lastSuccessExpiration)
        XCTAssertFalse(store.isAdFree)
    }

    func testMalformedTokenProducesInvalidFormat() async {
        let viewModel = CouponRegistrationViewModel()
        viewModel.inputToken = "no-separator-here"
        await viewModel.submit(
            verifier: { _, _ in
                XCTFail("verifier should not be called on parse failure")
                return false
            },
            store: store,
            context: context
        )
        XCTAssertEqual(viewModel.lastError, .invalidFormat)
    }

    // MARK: - verify failures

    func testFailedVerificationSurfacesRegistrationFailed() async throws {
        let viewModel = CouponRegistrationViewModel()
        viewModel.inputToken = "BAD.SIG"
        await viewModel.submit(
            verifier: { _, _ in false },
            store: store,
            context: context
        )

        XCTAssertEqual(viewModel.lastError, .registrationFailed)
        XCTAssertNil(viewModel.lastSuccessExpiration)
        XCTAssertFalse(store.isAdFree)
        // No row should have been written.
        let coupons = try context.fetch(FetchDescriptor<Coupon>())
        XCTAssertEqual(coupons.count, 0)
    }

    func testVerifierThrowingMapsToVerificationThrew() async throws {
        let viewModel = CouponRegistrationViewModel()
        viewModel.inputToken = "CODE.SIG"
        await viewModel.submit(
            verifier: { _, _ in throw CouponVerificationError.malformedSignature },
            store: store,
            context: context
        )

        XCTAssertEqual(viewModel.lastError, .verificationThrew)
        XCTAssertFalse(store.isAdFree)
        let coupons = try context.fetch(FetchDescriptor<Coupon>())
        XCTAssertEqual(coupons.count, 0)
    }

    // MARK: - duplicate

    func testDuplicateActiveCouponIsRejected() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = Coupon(
            code: "DUP",
            activatedAt: now,
            durationDays: 30,
            signatureBase64: "AA"
        )
        context.insert(existing)
        try context.save()
        store.refresh(now: now)

        let viewModel = CouponRegistrationViewModel()
        viewModel.inputToken = "DUP.SIG"
        await viewModel.submit(
            verifier: { _, _ in
                XCTFail("verifier should not be called on duplicate")
                return false
            },
            store: store,
            context: context,
            now: now
        )

        XCTAssertEqual(viewModel.lastError, .duplicate)
        // Still only the one row.
        let coupons = try context.fetch(FetchDescriptor<Coupon>())
        XCTAssertEqual(coupons.count, 1)
    }

    func testExpiredDuplicateIsAllowedToReregister() async throws {
        let twoYearsAgo = Date(timeIntervalSince1970: 1_500_000_000)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let stale = Coupon(
            code: "REUSE",
            activatedAt: twoYearsAgo,
            durationDays: 30,
            signatureBase64: "AA",
            status: .expired
        )
        context.insert(stale)
        try context.save()

        let viewModel = CouponRegistrationViewModel()
        viewModel.inputToken = "REUSE.NEW-SIG"
        await viewModel.submit(
            verifier: { _, _ in true },
            store: store,
            context: context,
            now: now
        )

        XCTAssertNil(viewModel.lastError)
        XCTAssertTrue(store.isAdFree)
        let coupons = try context.fetch(FetchDescriptor<Coupon>())
        XCTAssertEqual(coupons.count, 2)
    }
}
