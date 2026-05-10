import Foundation
import Observation

@MainActor
@Observable
final class AdFreeStore {
    private(set) var isAdFree: Bool = false

    private let fetcher: AdFreeStatusFetcher
    private let deviceHashProvider: DeviceHashProvider

    init(fetcher: AdFreeStatusFetcher, deviceHashProvider: DeviceHashProvider) {
        self.fetcher = fetcher
        self.deviceHashProvider = deviceHashProvider
    }

    func refresh() async {
        let hash = deviceHashProvider.deviceHash()
        guard let result = await fetcher.fetch(deviceHash: hash) else { return }
        isAdFree = result
    }
}
