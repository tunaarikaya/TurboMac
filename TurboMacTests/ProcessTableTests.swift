import XCTest
@testable import TurboMac

final class ProcessTableTests: XCTestCase {
    func test_processTree_returnsOnlyTheRoot_whenItHasNoChildren() {
        let table: [Int32: ProcInfo] = [
            1: ProcInfo(rss: 0, cpu: 0, ppid: 0, nice: 0)
        ]
        XCTAssertEqual(processTree(1, table: table), [1])
    }

    func test_processTree_includesAllDescendants_notJustDirectChildren() {
        // 1 -> 2 -> 3  and  1 -> 4  (Chrome/Electron gibi çok seviyeli süreç ağaçlarını simüle eder)
        let table: [Int32: ProcInfo] = [
            1: ProcInfo(rss: 0, cpu: 0, ppid: 0, nice: 0),
            2: ProcInfo(rss: 0, cpu: 0, ppid: 1, nice: 0),
            3: ProcInfo(rss: 0, cpu: 0, ppid: 2, nice: 0),
            4: ProcInfo(rss: 0, cpu: 0, ppid: 1, nice: 0),
            99: ProcInfo(rss: 0, cpu: 0, ppid: 5, nice: 0), // ilgisiz süreç, sonuca dahil olmamalı
        ]
        let result = Set(processTree(1, table: table))
        XCTAssertEqual(result, [1, 2, 3, 4])
    }

    func test_processTree_doesNotIncludeAncestorsOrSiblings() {
        let table: [Int32: ProcInfo] = [
            1: ProcInfo(rss: 0, cpu: 0, ppid: 0, nice: 0),
            2: ProcInfo(rss: 0, cpu: 0, ppid: 1, nice: 0),
            3: ProcInfo(rss: 0, cpu: 0, ppid: 1, nice: 0),
        ]
        let result = Set(processTree(2, table: table))
        XCTAssertEqual(result, [2])
    }
}
