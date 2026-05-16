import Foundation
@testable import PairShot
import Testing

struct ExportConcurrencyTests {
    @Test
    func `single core with abundant memory clamps to 1`() {
        let cap = ExportConcurrency.recommendedCap(cores: 1, availableMemoryBytes: 10 * 1024 * 1024 * 1024)
        #expect(cap == 1)
    }

    @Test
    func `four cores with abundant memory yields coreCap 2`() {
        let cap = ExportConcurrency.recommendedCap(cores: 4, availableMemoryBytes: 10 * 1024 * 1024 * 1024)
        #expect(cap == 2)
    }

    @Test
    func `six cores with abundant memory clamps to hardCap 3`() {
        let cap = ExportConcurrency.recommendedCap(cores: 6, availableMemoryBytes: 10 * 1024 * 1024 * 1024)
        #expect(cap == ExportConcurrency.hardCap)
        #expect(cap == 3)
    }

    @Test
    func `six cores with 200MB memory drops to 1`() {
        let cap = ExportConcurrency.recommendedCap(cores: 6, availableMemoryBytes: 200 * 1024 * 1024)
        #expect(cap == 1)
    }

    @Test
    func `six cores with avail 0 falls back to hardCap`() {
        let cap = ExportConcurrency.recommendedCap(cores: 6, availableMemoryBytes: 0)
        #expect(cap == ExportConcurrency.hardCap)
    }

    @Test
    func `six cores with negative avail falls back to hardCap`() {
        let cap = ExportConcurrency.recommendedCap(cores: 6, availableMemoryBytes: -1)
        #expect(cap == ExportConcurrency.hardCap)
    }

    @Test
    func `zero cores clamps to at least 1`() {
        let cap = ExportConcurrency.recommendedCap(cores: 0, availableMemoryBytes: 10 * 1024 * 1024 * 1024)
        #expect(cap >= 1)
    }

    @Test
    func `recommendedCap production wrapper is within bounds`() {
        let cap = ExportConcurrency.recommendedCap()
        #expect(cap >= 1)
        #expect(cap <= ExportConcurrency.hardCap)
    }
}
