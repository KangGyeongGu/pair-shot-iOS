import Foundation
@testable import PairShot
import StoreKit
import StoreKitTest
import Testing

@MainActor
struct ProductsServiceTests {
    @Test("loadProducts populates configured monthly and annual products")
    func loadProductsReturnsConfiguredProducts() async throws {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.disableDialogs = true
        session.clearTransactions()

        let service = ProductsService()
        try await service.loadProducts()

        let identifiers = Set(service.products.map(\.id))
        #expect(identifiers == ProductIDs.allProSet)
        _ = session
    }

    @Test("loadProducts returns subscription products with non-empty display name")
    func loadedProductsHaveDisplayName() async throws {
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

    @Test("loadProducts initial state has empty products array")
    func initialStateIsEmpty() {
        let service = ProductsService()
        #expect(service.products.isEmpty)
    }
}
