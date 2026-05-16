import Darwin
import Foundation

nonisolated enum ExportConcurrency {
    static let hardCap = 3
    static let perPairBudgetBytes = 60 * 1024 * 1024

    static func recommendedCap() -> Int {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let avail = availableMemoryBytes()
        return recommendedCap(cores: cores, availableMemoryBytes: avail)
    }

    static func recommendedCap(cores: Int, availableMemoryBytes: Int) -> Int {
        let coreCap = max(1, cores - 2)
        let memCap: Int = {
            guard availableMemoryBytes > 0 else { return hardCap }
            return max(1, availableMemoryBytes / perPairBudgetBytes / 2)
        }()
        return max(1, min(hardCap, coreCap, memCap))
    }

    private static func availableMemoryBytes() -> Int {
        Int(os_proc_available_memory())
    }
}
