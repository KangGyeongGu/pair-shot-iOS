import SwiftData
import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct PairShotApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([Project.self, PhotoPair.self, Coupon.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // P6.1: bootstrap the Google Mobile Ads SDK as early as possible so
        // ad surfaces (P6.5+) have a warm SDK by the time they appear. The
        // call is idempotent and non-blocking — fine to fire-and-forget
        // from the App initialiser. Wrapped in `canImport` so the project
        // still compiles in environments where the SPM dependency hasn't
        // resolved (CI sandboxes, fresh checkouts before package fetch).
        // v11 SDK exposes `GADMobileAds.sharedInstance().start(...)`; v12+
        // renames to `MobileAds.shared.start(...)`. We use the v11 names
        // since that is the resolved minimum version.
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
