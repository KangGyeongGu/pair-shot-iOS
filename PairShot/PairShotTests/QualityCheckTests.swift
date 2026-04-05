import CoreImage
@testable import PairShot
import Testing
import UIKit

struct QualityCheckTests {
    @Test func qualityIssue_enumHasExpectedCases() {
        let blurry: QualityIssue = .blurry
        let over: QualityIssue = .overExposed
        let under: QualityIssue = .underExposed
        #expect(blurry != over)
        #expect(over != under)
    }

    @Test @MainActor func service_initialState_noIssueAndNotAnalyzing() {
        let service = QualityCheckService()
        #expect(service.lastIssue == nil)
        #expect(service.isAnalyzing == false)
    }
}

extension QualityIssue: Equatable {}
