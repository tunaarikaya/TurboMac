import AppKit

// MARK: - App row

struct AppRow: Identifiable {
    let id: Int32
    let bundleID: String
    let name: String
    let icon: NSImage?
    var ram: UInt64
    var cpu: Double
    var nice: Int
    var priority: Priority
    var procCount: Int
    /// Kural konuldu ama uygulama o tarihten sonra yeniden başlatılmadı.
    /// macOS süreç politikasını yalnızca başlangıçta kabul ettiği için
    /// bu durumda ayar henüz TAM olarak geçerli değil.
    var needsRestart: Bool

    /// Kural yok → durum satırı da yok.
    var hasRule: Bool { priority != .normal }
}
