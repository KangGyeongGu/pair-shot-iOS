import Observation
import StoreKit

@MainActor
@Observable
final class ProductsService {
    private(set) var products: [Product] = []

    func loadProducts() async throws {
        let loaded = try await Product.products(for: ProductIDs.allLoadable)
        products = loaded
    }
}
