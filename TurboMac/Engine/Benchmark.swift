import Foundation

// MARK: - Ölçüm testi (mekanizma bu Mac'te gerçekten çalışıyor mu)

struct BenchResult {
    var normal: Int = 0
    var throttled: Int = 0
    var runtimeBoost: Int = 0
    var ratio: Double { throttled == 0 ? 0 : Double(normal) / Double(throttled) }
    var runtimeWorks: Bool { normal > 0 && Double(runtimeBoost) > Double(normal) * 0.7 }
}

enum Bench {
    static let loop = "i=0; e=$((SECONDS+3)); while [ $SECONDS -lt $e ]; do i=$((i+1)); done; echo $i"

    static func run() -> BenchResult {
        var r = BenchResult()
        r.normal = Int(sh("/bin/sh", ["-c", loop])
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        r.throttled = Int(sh("/usr/sbin/taskpolicy",
                             ["-b", "-t", "2", "-l", "2", "/bin/sh", "-c", loop])
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        // Kısık başlatılan bir sürece ÇALIŞIRKEN -B uygulanınca toparlıyor mu?
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/taskpolicy")
        p.arguments = ["-b", "-t", "2", "-l", "2", "/bin/sh", "-c", loop]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        Thread.sleep(forTimeInterval: 0.4)
        sh("/usr/sbin/taskpolicy", ["-B", "-t", "0", "-l", "0", "-p", "\(p.processIdentifier)"])
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        r.runtimeBoost = Int(String(data: d, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
        return r
    }
}
