import SwiftUI
import Darwin

// MARK: - System stats

struct SysStats {
    var ramTotal: UInt64 = 0
    var ramUsed: UInt64 = 0
    var ramWired: UInt64 = 0
    var ramCompressed: UInt64 = 0
    var ramCached: UInt64 = 0
    var pressure: Int = 1          // 1 normal, 2 warn, 4 critical
    var swapUsed: UInt64 = 0
    var gpuUtil: Int = 0
    var gpuMem: UInt64 = 0
    var cpuUser: Double = 0
    var cpuSys: Double = 0
    var cpuIdle: Double = 100

    var ramPct: Double { ramTotal == 0 ? 0 : Double(ramUsed) / Double(ramTotal) * 100 }
    var cpuPct: Double { 100 - cpuIdle }
    var pressureColor: Color {
        switch pressure { case 4: return .red; case 2: return .orange; default: return .green }
    }
}

final class Sampler {
    private var lastCPU: host_cpu_load_info?

    func totalRAM() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }

    func vmStats() -> vm_statistics64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        return stats
    }

    func pressureLevel() -> Int {
        var lvl: Int32 = 1
        var len = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &lvl, &len, nil, 0)
        return Int(lvl)
    }

    func swapUsed() -> UInt64 {
        var xsw = xsw_usage()
        var len = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &xsw, &len, nil, 0)
        return xsw.xsu_used
    }

    func cpuLoad() -> (Double, Double, Double) {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0, 100) }
        defer { lastCPU = info }
        guard let prev = lastCPU else { return (0, 0, 100) }
        let u = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let s = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let i = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let n = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = u + s + i + n
        guard total > 0 else { return (0, 0, 100) }
        return ((u + n) / total * 100, s / total * 100, i / total * 100)
    }

    func gpu() -> (Int, UInt64) {
        let out = sh("/usr/sbin/ioreg", ["-r", "-c", "IOAccelerator", "-w0"])
        var util = 0
        var mem: UInt64 = 0
        for line in out.split(separator: "\n") where line.contains("PerformanceStatistics") {
            if let v = grab(line, key: "\"Device Utilization %\"=") { util = max(util, Int(v) ?? 0) }
            if let v = grab(line, key: "\"In use system memory\"=") { mem = max(mem, UInt64(v) ?? 0) }
        }
        return (util, mem)
    }

    private func grab(_ line: Substring, key: String) -> String? {
        guard let r = line.range(of: key) else { return nil }
        let digits = line[r.upperBound...].prefix { $0.isNumber }
        return digits.isEmpty ? nil : String(digits)
    }

    func snapshot() -> SysStats {
        var s = SysStats()
        let page = UInt64(vm_kernel_page_size)
        let vm = vmStats()
        s.ramTotal = totalRAM()
        s.ramWired = UInt64(vm.wire_count) * page
        s.ramCompressed = UInt64(vm.compressor_page_count) * page
        s.ramCached = UInt64(vm.external_page_count) * page
        let active = UInt64(vm.active_count) * page
        let inactive = UInt64(vm.inactive_count) * page
        s.ramUsed = active + inactive + s.ramWired + s.ramCompressed - s.ramCached
        s.pressure = pressureLevel()
        s.swapUsed = swapUsed()
        let (u, sy, idle) = cpuLoad()
        s.cpuUser = u; s.cpuSys = sy; s.cpuIdle = idle
        let (g, gm) = gpu()
        s.gpuUtil = g; s.gpuMem = gm
        return s
    }
}
