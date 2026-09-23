import XCTest
@testable import TurboMac

final class BenchmarkTests: XCTestCase {
    func test_ratio_isZero_whenThrottledCountIsZero() {
        var r = BenchResult()
        r.normal = 1_000_000
        r.throttled = 0
        XCTAssertEqual(r.ratio, 0)
    }

    func test_ratio_computesHowManyTimesFasterNormalRunIs() {
        var r = BenchResult()
        r.normal = 1_000_000
        r.throttled = 250_000
        XCTAssertEqual(r.ratio, 4.0, accuracy: 0.0001)
    }

    func test_runtimeWorks_isFalse_whenNormalCountIsZero() {
        var r = BenchResult()
        r.normal = 0
        r.runtimeBoost = 999_999
        XCTAssertFalse(r.runtimeWorks)
    }

    func test_runtimeWorks_isTrue_whenBoostRecoversAtLeast70PercentOfNormal() {
        var r = BenchResult()
        r.normal = 1_000_000
        r.runtimeBoost = 700_001
        XCTAssertTrue(r.runtimeWorks)
    }

    func test_runtimeWorks_isFalse_justBelowThe70PercentThreshold() {
        var r = BenchResult()
        r.normal = 1_000_000
        r.runtimeBoost = 699_999
        XCTAssertFalse(r.runtimeWorks)
    }
}
