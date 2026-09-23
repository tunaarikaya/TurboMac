import XCTest
@testable import TurboMac

final class PriorityTests: XCTestCase {
    func test_niceValue_mapsToExpectedUnixNiceLevels() {
        XCTAssertEqual(Priority.low.niceValue, 15)
        XCTAssertEqual(Priority.normal.niceValue, 0)
        XCTAssertEqual(Priority.turbo.niceValue, -10)
        XCTAssertEqual(Priority.max.niceValue, -20)
    }

    func test_needsAdmin_isTrueOnlyForNegativeNiceValues() {
        XCTAssertFalse(Priority.low.needsAdmin)
        XCTAssertFalse(Priority.normal.needsAdmin)
        XCTAssertTrue(Priority.turbo.needsAdmin)
        XCTAssertTrue(Priority.max.needsAdmin)
    }

    func test_shortTR_andShortEN_haveALabelForEveryCase() {
        for p in Priority.allCases {
            XCTAssertFalse(p.shortTR.isEmpty)
            XCTAssertFalse(p.shortEN.isEmpty)
        }
    }

    func test_allCases_areOrderedFromLowestToHighestNiceValue() {
        // niceValue düşük = daha yüksek öncelik; sıralama Priority'nin işlevsel özünü doğrular.
        let sortedByNice = Priority.allCases.sorted { $0.niceValue > $1.niceValue }
        XCTAssertEqual(sortedByNice, [.low, .normal, .turbo, .max])
    }
}
