import XCTest
@testable import TurboMac

final class SystemStatsTests: XCTestCase {
    func test_ramPct_isZero_whenTotalRAMIsZero() {
        var s = SysStats()
        s.ramTotal = 0
        s.ramUsed = 500
        XCTAssertEqual(s.ramPct, 0)
    }

    func test_ramPct_computesPercentageOfUsedOverTotal() {
        var s = SysStats()
        s.ramTotal = 16_000_000_000
        s.ramUsed = 8_000_000_000
        XCTAssertEqual(s.ramPct, 50.0, accuracy: 0.0001)
    }

    func test_cpuPct_isComplementOfIdle() {
        var s = SysStats()
        s.cpuIdle = 30
        XCTAssertEqual(s.cpuPct, 70)
    }

    func test_pressureColor_mapsEachPressureLevelToExpectedColor() {
        var s = SysStats()
        s.pressure = 4
        XCTAssertEqual(s.pressureColor, .red)
        s.pressure = 2
        XCTAssertEqual(s.pressureColor, .orange)
        s.pressure = 1
        XCTAssertEqual(s.pressureColor, .green)
        s.pressure = 0
        XCTAssertEqual(s.pressureColor, .green) // tanımsız/normal değer güvenli varsayılana düşmeli
    }
}
