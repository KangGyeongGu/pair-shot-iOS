import Foundation
import OSLog

nonisolated enum AppLogger {
    private static let subsystem: String =
        Bundle.main.bundleIdentifier ?? "com.pairshot"

    nonisolated static let camera = Logger(subsystem: subsystem, category: "Camera")
    nonisolated static let storage = Logger(subsystem: subsystem, category: "Storage")
    nonisolated static let ads = Logger(subsystem: subsystem, category: "Ads")
}
