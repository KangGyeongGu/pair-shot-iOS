import Darwin
import Foundation

nonisolated enum ExportConcurrency {
    struct CapDetails {
        let cap: Int
        let cores: Int
        let availableMemoryBytes: Int
        let memCap: Int
        let coreCap: Int
        let hardCap: Int
    }

    static let hardCap = 3
    static let perPairBudgetBytes = 60 * 1024 * 1024

    static func recommendedCap() -> Int {
        recommendedCapDetails().cap
    }

    static func recommendedCapDetails() -> CapDetails {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let avail = availableMemoryBytes()
        return recommendedCapDetails(cores: cores, availableMemoryBytes: avail)
    }

    static func recommendedCap(cores: Int, availableMemoryBytes: Int) -> Int {
        recommendedCapDetails(cores: cores, availableMemoryBytes: availableMemoryBytes).cap
    }

    static func recommendedCapDetails(cores: Int, availableMemoryBytes: Int) -> CapDetails {
        let coreCap = max(1, cores - 2)
        let memCap: Int = {
            guard availableMemoryBytes > 0 else { return hardCap }
            return max(1, availableMemoryBytes / perPairBudgetBytes / 2)
        }()
        let cap = max(1, min(hardCap, coreCap, memCap))
        return CapDetails(
            cap: cap,
            cores: cores,
            availableMemoryBytes: availableMemoryBytes,
            memCap: memCap,
            coreCap: coreCap,
            hardCap: hardCap,
        )
    }

    private static func availableMemoryBytes() -> Int {
        Int(os_proc_available_memory())
    }
}
