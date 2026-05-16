import Foundation
@testable import PairShot
import StoreKit
import StoreKitTest
import Testing

@MainActor
struct ProductsServiceTests {
    @Test(
        .disabled("Xcode 26 SKTestSession 회귀 — Apple radar 트래킹"),
    )
    func `loadProducts populates configured monthly and annual products`() async throws {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.disableDialogs = true
        session.clearTransactions()

        let service = ProductsService()
        try await service.loadProducts()

        let identifiers = Set(service.products.map(\.id))
        #expect(identifiers == ProductIDs.allProSet)
        _ = session
    }

    @Test(
        .disabled("Xcode 26 SKTestSession 회귀 — Apple radar 트래킹"),
    )
    func `loadProducts returns subscription products with non-empty display name`() async throws {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.disableDialogs = true
        session.clearTransactions()

        let service = ProductsService()
        try await service.loadProducts()

        for product in service.products {
            #expect(!product.displayName.isEmpty)
            #expect(!product.displayPrice.isEmpty)
            #expect(product.subscription != nil)
        }
        _ = session
    }

    @Test
    func `loadProducts initial state has empty products array`() {
        let service = ProductsService()
        #expect(service.products.isEmpty)
    }
}
