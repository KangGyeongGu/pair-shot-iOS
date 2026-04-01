import Testing
@testable import PairShot

@MainActor
struct TimerDurationTests {

    // MARK: - seconds happy path

    @Test func seconds_off_isZero() {
        #expect(TimerDuration.off.seconds == 0)
    }

    @Test func seconds_threeSeconds_isThree() {
        #expect(TimerDuration.threeSeconds.seconds == 3)
    }

    @Test func seconds_tenSeconds_isTen() {
        #expect(TimerDuration.tenSeconds.seconds == 10)
    }

    // MARK: - seconds boundary

    @Test func seconds_offIsMinimum() {
        let minimum = TimerDuration.allCases.map { $0.seconds }.min()
        #expect(minimum == 0)
    }

    @Test func seconds_tenSecondsIsMaximum() {
        let maximum = TimerDuration.allCases.map { $0.seconds }.max()
        #expect(maximum == 10)
    }

    // MARK: - seconds negative

    @Test func seconds_allValuesAreNonNegative() {
        for duration in TimerDuration.allCases {
            #expect(duration.seconds >= 0)
        }
    }

    // MARK: - seconds error

    @Test func seconds_allCasesAreDistinct() {
        let values = TimerDuration.allCases.map { $0.seconds }
        let unique = Set(values)
        #expect(unique.count == TimerDuration.allCases.count)
    }

    // MARK: - displayName happy path

    @Test func displayName_off_returnsOFF() {
        #expect(TimerDuration.off.displayName == "OFF")
    }

    @Test func displayName_threeSeconds_returns3s() {
        #expect(TimerDuration.threeSeconds.displayName == "3s")
    }

    @Test func displayName_tenSeconds_returns10s() {
        #expect(TimerDuration.tenSeconds.displayName == "10s")
    }

    // MARK: - displayName boundary

    @Test func displayName_allCasesAreNonEmpty() {
        for duration in TimerDuration.allCases {
            #expect(duration.displayName.isEmpty == false)
        }
    }

    // MARK: - displayName negative

    @Test func displayName_allCasesAreDistinct() {
        let names = TimerDuration.allCases.map { $0.displayName }
        let unique = Set(names)
        #expect(unique.count == TimerDuration.allCases.count)
    }

    // MARK: - displayName error

    @Test func displayName_offDoesNotContainDigits() {
        // "OFF"는 숫자를 포함하지 않아야 한다
        let name = TimerDuration.off.displayName
        #expect(name.first(where: { $0.isNumber }) == nil)
    }
}
