import Foundation

struct DomainLocation: Equatable {
    let latitude: Double
    let longitude: Double
}

protocol LocationFetching: Sendable {
    func fetchOnce() async -> DomainLocation?
}
