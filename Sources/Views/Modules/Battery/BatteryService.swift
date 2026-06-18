import Foundation
import IOKit.ps
import Combine

/// Reads battery state via IOKit power sources. Updates instantly on power
/// changes (run-loop source) plus a slow safety poll.
final class BatteryService: ObservableObject {
    static let shared = BatteryService()

    @Published var percent: Int = 100
    @Published var isCharging = false
    @Published var isPluggedIn = false
    @Published var isPresent = true
    /// Minutes remaining (to full when charging, to empty otherwise). nil = "calculating".
    @Published var minutesRemaining: Int?

    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private init() {}

    func start() {
        refresh()

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let me = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { me.refresh() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, ctx)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        guard let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any]
        else { isPresent = false; return }

        isPresent = true
        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? percent
        let maximum = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : current

        isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false

        let key = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
        if let t = desc[key] as? Int, t >= 0 { minutesRemaining = t } else { minutesRemaining = nil }
    }
}
