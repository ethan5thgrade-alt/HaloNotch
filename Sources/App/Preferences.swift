import SwiftUI
import ServiceManagement

/// The visual material behind the expanded panel.
enum NotchMaterial: String, CaseIterable, Identifiable {
    case glass   // System translucent material (Liquid Glass on macOS 26+, vibrancy below)
    case black   // Opaque black, matches the physical notch all the way down
    case auto    // Glass when expanded, black when idle

    var id: String { rawValue }
    var label: String {
        switch self {
        case .glass: return "Glass (system material)"
        case .black: return "Black (notch-matched)"
        case .auto:  return "Auto"
        }
    }
}

/// How the now-playing data is sourced.
enum NowPlayingSourceKind: String, CaseIterable, Identifiable {
    case auto         // Adapter if installed, else AppleScript
    case adapter      // Universal MediaRemote adapter only
    case appleScript  // Spotify + Apple Music only

    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto:         return "Auto (best available)"
        case .adapter:      return "Universal (MediaRemote adapter)"
        case .appleScript:  return "Spotify + Apple Music only"
        }
    }
}

/// All user-tunable settings, persisted to UserDefaults. Singleton so both the
/// SwiftUI scenes (MenuBarExtra / Settings) and the AppKit-hosted notch view
/// share one instance.
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let d = UserDefaults.standard

    private enum K {
        static let material = "material"
        static let openOnHover = "openOnHover"
        static let animationSpeed = "animationSpeed"
        static let showVisualizer = "showVisualizer"
        static let nowPlayingSource = "nowPlayingSource"
        static let recordSkin = "recordSkin"
        static let launchAtLogin = "launchAtLogin"
        static let modNowPlaying = "moduleNowPlaying"
        static let modBattery = "moduleBattery"
        static let modClock = "moduleClock"
        static let modTimer = "moduleTimer"
        static let modSchool = "moduleSchool"
        static let notchWidthPadding = "notchWidthPadding"
        static let alexaAutoConnect = "alexaAutoConnect"
        static let alexaDeviceName = "alexaDeviceName"
    }

    @Published var material: NotchMaterial {
        didSet { d.set(material.rawValue, forKey: K.material) }
    }
    /// When true, the notch opens on hover; when false, it opens on click.
    @Published var openOnHover: Bool { didSet { d.set(openOnHover, forKey: K.openOnHover) } }
    /// 0.5 (snappier) … 1.5 (more languid). Multiplies the base spring response.
    @Published var animationSpeed: Double { didSet { d.set(animationSpeed, forKey: K.animationSpeed) } }
    @Published var showVisualizer: Bool { didSet { d.set(showVisualizer, forKey: K.showVisualizer) } }
    @Published var nowPlayingSource: NowPlayingSourceKind {
        didSet { d.set(nowPlayingSource.rawValue, forKey: K.nowPlayingSource) }
    }
    /// Which Now Playing media skin shows (vinyl / cassette / CD). Tap to cycle.
    @Published var recordSkin: RecordSkin {
        didSet { d.set(recordSkin.rawValue, forKey: K.recordSkin) }
    }
    func cycleRecordSkin() { recordSkin = recordSkin.next }

    // Module toggles
    @Published var moduleNowPlaying: Bool { didSet { d.set(moduleNowPlaying, forKey: K.modNowPlaying) } }
    @Published var moduleBattery: Bool { didSet { d.set(moduleBattery, forKey: K.modBattery) } }
    @Published var moduleClock: Bool { didSet { d.set(moduleClock, forKey: K.modClock) } }
    @Published var moduleTimer: Bool { didSet { d.set(moduleTimer, forKey: K.modTimer) } }
    @Published var moduleSchool: Bool { didSet { d.set(moduleSchool, forKey: K.modSchool) } }

    /// Extra width added to each side of the detected notch (only used when no
    /// physical notch exists and we synthesize a floating pill).
    @Published var notchWidthPadding: Double { didSet { d.set(notchWidthPadding, forKey: K.notchWidthPadding) } }

    /// Alexa: connect to the paired Echo automatically whenever music starts.
    @Published var alexaAutoConnect: Bool { didSet { d.set(alexaAutoConnect, forKey: K.alexaAutoConnect) } }
    /// Alexa: substring of the Echo's Bluetooth name. Empty = any device with "Echo" in its name.
    @Published var alexaDeviceName: String { didSet { d.set(alexaDeviceName, forKey: K.alexaDeviceName) } }

    @Published var launchAtLogin: Bool {
        didSet {
            d.set(launchAtLogin, forKey: K.launchAtLogin)
            syncLoginItem()
        }
    }

    private init() {
        material = NotchMaterial(rawValue: d.string(forKey: K.material) ?? "") ?? .glass
        openOnHover = d.object(forKey: K.openOnHover) as? Bool ?? true
        animationSpeed = d.object(forKey: K.animationSpeed) as? Double ?? 1.0
        showVisualizer = d.object(forKey: K.showVisualizer) as? Bool ?? true
        nowPlayingSource = NowPlayingSourceKind(rawValue: d.string(forKey: K.nowPlayingSource) ?? "") ?? .auto
        recordSkin = RecordSkin(rawValue: d.string(forKey: K.recordSkin) ?? "") ?? .vinyl
        moduleNowPlaying = d.object(forKey: K.modNowPlaying) as? Bool ?? true
        moduleBattery = d.object(forKey: K.modBattery) as? Bool ?? true
        moduleClock = d.object(forKey: K.modClock) as? Bool ?? true
        moduleTimer = d.object(forKey: K.modTimer) as? Bool ?? true
        moduleSchool = d.object(forKey: K.modSchool) as? Bool ?? true
        notchWidthPadding = d.object(forKey: K.notchWidthPadding) as? Double ?? 0
        launchAtLogin = d.object(forKey: K.launchAtLogin) as? Bool ?? false
        alexaAutoConnect = d.object(forKey: K.alexaAutoConnect) as? Bool ?? false
        alexaDeviceName = d.string(forKey: K.alexaDeviceName) ?? ""
    }

    private func syncLoginItem() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("HaloNotch: login-item toggle failed: \(error)")
        }
    }

    // MARK: - Animation

    /// Spring used when the notch expands. Scaled by `animationSpeed`.
    var openAnimation: Animation {
        .spring(response: 0.42 * animationSpeed, dampingFraction: 0.72, blendDuration: 0)
    }
    /// Slightly snappier, better-damped spring for the collapse.
    var closeAnimation: Animation {
        .spring(response: 0.34 * animationSpeed, dampingFraction: 0.86, blendDuration: 0)
    }
}
