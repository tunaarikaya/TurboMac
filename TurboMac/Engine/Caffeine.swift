import Foundation
import IOKit.pwr_mgt

// MARK: - Uyanık tutma (MAX modda idle kısmasını engeller)

/// MAX seviyesinde bir uygulama varken Mac'in boşta uyumasını engeller.
///
/// Burada `caffeinate` süreci ÇALIŞTIRMIYORUZ. Alt süreç yaklaşımının gerçek bir
/// sorunu vardı: TurboMac kapandığında (çökme, Xcode'dan durdurma, yeniden
/// derleme) caffeinate yetim kalıp yaşamaya devam ediyor ve Mac'i sonsuza kadar
/// uyanık tutuyordu — ölçümde 5 kaçak süreç birikmişti.
///
/// IOKit güç yönetimi iddiası (power assertion) sürecimize bağlıdır: TurboMac
/// nasıl sonlanırsa sonlansın çekirdek iddiayı otomatik olarak serbest bırakır.
/// Sızdırması mümkün değil.
final class Caffeine {
    static let shared = Caffeine()

    private var assertionID: IOPMAssertionID = 0
    private(set) var active = false

    func start() {
        guard !active else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "TurboMac: an app is set to MAX" as CFString,
            &id)
        guard result == kIOReturnSuccess else { return }
        assertionID = id
        active = true
    }

    func stop() {
        guard active else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        active = false
    }

    /// Eski sürümlerin bıraktığı kaçak `caffeinate -dimsu` süreçlerini temizler.
    /// Yalnızca bu kullanıcıya ait olanlara dokunur ve açılışta bir kez çalışır.
    static func cleanUpLegacyProcesses() {
        sh("/usr/bin/pkill", ["-U", "\(getuid())", "-f", "^/usr/bin/caffeinate -dimsu$"])
    }
}
