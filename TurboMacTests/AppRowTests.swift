import XCTest
@testable import TurboMac

final class AppRowTests: XCTestCase {
    private func makeRow(priority: Priority) -> AppRow {
        AppRow(id: 1, bundleID: "com.test.app", name: "Test", icon: nil,
               ram: 0, cpu: 0, nice: 0, priority: priority, procCount: 1,
               needsRestart: false)
    }

    func test_hasRule_isFalse_forNormalPriority() {
        XCTAssertFalse(makeRow(priority: .normal).hasRule)
    }

    func test_hasRule_isTrue_forAnyNonNormalPriority() {
        XCTAssertTrue(makeRow(priority: .low).hasRule)
        XCTAssertTrue(makeRow(priority: .turbo).hasRule)
        XCTAssertTrue(makeRow(priority: .max).hasRule)
    }
}
