import Foundation

// MARK: - Process table

struct ProcInfo { var rss: UInt64 = 0; var cpu: Double = 0; var ppid: Int32 = 0; var nice: Int = 0 }

func procTable() -> [Int32: ProcInfo] {
    let out = sh("/bin/ps", ["-Ao", "pid=,ppid=,rss=,%cpu=,nice="])
    var map: [Int32: ProcInfo] = [:]
    for line in out.split(separator: "\n") {
        let f = line.split(separator: " ", omittingEmptySubsequences: true)
        guard f.count >= 5, let pid = Int32(f[0]), let ppid = Int32(f[1]),
              let rss = UInt64(f[2]) else { continue }
        let cpu = Double(f[3].replacingOccurrences(of: ",", with: ".")) ?? 0
        map[pid] = ProcInfo(rss: rss * 1024, cpu: cpu, ppid: ppid, nice: Int(f[4]) ?? 0)
    }
    return map
}

/// pid + tüm alt süreçleri (Chrome/Electron/Terminal sekmeleri için şart)
func processTree(_ root: Int32, table: [Int32: ProcInfo]) -> [Int32] {
    var children: [Int32: [Int32]] = [:]
    for (pid, info) in table { children[info.ppid, default: []].append(pid) }
    var result: [Int32] = []
    var stack = [root]
    while let p = stack.popLast() {
        result.append(p)
        if let kids = children[p] { stack.append(contentsOf: kids) }
    }
    return result
}
