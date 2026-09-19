import Foundation

// MARK: - Shell

/// Bir komutu çalıştırır, standart çıktısını döner.
///
/// stderr için Pipe KULLANMIYORUZ: okunmayan bir pipe 64 KB'a dolunca
/// yazan süreç bloke olur ve `waitUntilExit()` sonsuza kadar bekler.
/// Hata çıktısı bizi ilgilendirmiyorsa /dev/null'a yazdırmak tek güvenli yol.
@discardableResult
func sh(_ cmd: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: cmd)
    p.arguments = args
    let out = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    p.standardInput = FileHandle.nullDevice
    do { try p.run() } catch { return "" }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

/// Komutu çalıştırır; çıkış kodunu, stdout ve stderr'i birlikte döner.
@discardableResult
func shFull(_ cmd: String, _ args: [String]) -> (code: Int32, out: String, err: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: cmd)
    p.arguments = args
    let o = Pipe(), e = Pipe()
    p.standardOutput = o
    p.standardError = e
    p.standardInput = FileHandle.nullDevice
    do { try p.run() } catch { return (-1, "", "\(error)") }
    // İki pipe'ı da paralel boşalt, yoksa biri dolunca kilitlenir.
    var outData = Data(), errData = Data()
    let g = DispatchGroup()
    DispatchQueue.global().async(group: g) { outData = o.fileHandleForReading.readDataToEndOfFile() }
    DispatchQueue.global().async(group: g) { errData = e.fileHandleForReading.readDataToEndOfFile() }
    g.wait()
    p.waitUntilExit()
    return (p.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? "")
}

/// Yönetici şifresiyle çalıştırır. Kullanıcı iptal ederse `false` döner.
///
/// osascript hatayı stderr'e yazdığı için `sh()` ile iptali ASLA anlayamayız;
/// bu yüzden burada stderr'i de okuyan `shFull` kullanılıyor.
@discardableResult
func adminSh(_ script: String) -> Bool {
    let esc = script.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
    let r = shFull("/usr/bin/osascript",
                   ["-e", "do shell script \"\(esc)\" with administrator privileges"])
    return r.code == 0
}

func bytesStr(_ b: UInt64) -> String {
    let g = Double(b) / 1_073_741_824
    if g >= 1 { return String(format: "%.1f GB", g) }
    return String(format: "%.0f MB", Double(b) / 1_048_576)
}
