import Foundation
import IOBluetooth
import CoreAudio
import SwiftUI
import Combine

/// Sends the Mac's audio to an Amazon Echo over Bluetooth.
///
/// Amazon has no public API for streaming arbitrary audio to an Echo, but every
/// Echo is a standard Bluetooth A2DP speaker. So "play on Alexa" = connect the
/// paired Echo, wait for it to show up as a CoreAudio output, make it the
/// default output, then resume playback. Disconnecting hands audio back to the
/// built-in speakers (macOS does that on its own when the device drops).
///
/// First-time setup: say "Alexa, pair Bluetooth", then hit "Pair" in the tray
/// (or pair it once in System Settings > Bluetooth).
final class AlexaSpeaker: NSObject, ObservableObject {
    static let shared = AlexaSpeaker()

    enum Status: Equatable {
        case notPaired           // no Echo in the Mac's paired list
        case idle                // paired, not connected
        case searching           // running a Bluetooth inquiry to pair
        case connecting
        case connected           // connected AND default output
        case failed(String)
    }

    @Published private(set) var status: Status = .notPaired
    @Published private(set) var deviceName: String?

    private var inquiry: IOBluetoothDeviceInquiry?
    private var pairing: IOBluetoothDevicePair?
    private let work = DispatchQueue(label: "halonotch.alexa")
    private var playingSub: AnyCancellable?

    /// Name match for Echo devices ("Echo Dot-1AB", "Echo Pop-XYZ", "Echo Studio"...).
    /// Users can override with a substring in Settings.
    private var nameHint: String {
        let h = Preferences.shared.alexaDeviceName.trimmingCharacters(in: .whitespaces)
        return h.isEmpty ? "echo" : h.lowercased()
    }

    override private init() {
        super.init()
        refresh()
    }

    // MARK: - Public

    var isConnected: Bool { status == .connected }

    /// Re-read the paired list and current connection/output state.
    func refresh() {
        guard let dev = pairedEcho() else {
            if status != .searching { status = .notPaired }
            deviceName = nil
            return
        }
        deviceName = dev.name
        if dev.isConnected(), defaultOutputIsEcho(dev) {
            status = .connected
        } else if status != .connecting {
            status = .idle
        }
    }

    /// Tap action: connect + route + play, or disconnect if already on the Echo.
    func toggle() {
        refresh()
        switch status {
        case .connected: disconnect()
        case .notPaired, .failed: if pairedEcho() == nil { pairNew() } else { connectAndPlay() }
        case .idle: connectAndPlay()
        case .searching, .connecting: break
        }
    }

    func connectAndPlay() {
        guard let dev = pairedEcho() else { status = .notPaired; return }
        status = .connecting
        deviceName = dev.name
        let address = dev.addressString ?? ""
        let name = dev.name ?? ""
        work.async { [weak self] in
            guard let self else { return }
            if !dev.isConnected() {
                let r = dev.openConnection()   // blocking; ~1-5s
                if r != kIOReturnSuccess {
                    self.fail("Couldn't reach \(name). Is it on and nearby?")
                    return
                }
            }
            // The A2DP output shows up in CoreAudio a beat after the link opens.
            var outID: AudioDeviceID?
            for _ in 0..<40 {   // up to ~8s
                if let id = Self.audioOutput(matchingName: name, address: address) { outID = id; break }
                Thread.sleep(forTimeInterval: 0.2)
            }
            guard let outID else {
                self.fail("\(name) connected but never showed up as a speaker.")
                return
            }
            Self.setDefaultOutput(outID)
            DispatchQueue.main.async {
                self.status = .connected
                // Give the route a moment to settle, then make sure music is going.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let np = NowPlayingController.shared
                    if np.info.hasContent, !np.info.isPlaying { np.togglePlayPause() }
                }
            }
        }
    }

    func disconnect() {
        guard let dev = pairedEcho() else { refresh(); return }
        work.async { [weak self] in
            dev.closeConnection()
            DispatchQueue.main.async {
                self?.status = .idle
            }
        }
    }

    /// Discover an Echo in pairing mode ("Alexa, pair Bluetooth") and pair it.
    func pairNew() {
        guard inquiry == nil else { return }
        status = .searching
        let inq = IOBluetoothDeviceInquiry(delegate: self)
        inq?.inquiryLength = 12
        inq?.updateNewDeviceNames = true
        inquiry = inq
        if inq?.start() != kIOReturnSuccess {
            inquiry = nil
            fail("Bluetooth search failed. Is Bluetooth on?")
        }
    }

    /// Watch playback so auto-connect can fire when music starts.
    func startObserving() {
        guard playingSub == nil else { return }
        playingSub = NowPlayingController.shared.$info
            .map(\.isPlaying)
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.playbackStarted() }
    }

    /// Auto-connect hook: called when playback starts.
    func playbackStarted() {
        guard Preferences.shared.alexaAutoConnect else { return }
        refresh()
        if status == .idle { connectAndPlay() }
    }

    // MARK: - Bluetooth helpers

    private func matches(_ name: String?) -> Bool {
        guard let n = name?.lowercased() else { return false }
        return n.contains(nameHint)
    }

    private func pairedEcho() -> IOBluetoothDevice? {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        // Prefer one that's already connected, then most recently used.
        let echoes = paired.filter { matches($0.name) }
        return echoes.first(where: { $0.isConnected() })
            ?? echoes.max(by: { ($0.recentAccessDate() ?? .distantPast) < ($1.recentAccessDate() ?? .distantPast) })
    }

    private func fail(_ msg: String) {
        DispatchQueue.main.async {
            self.status = .failed(msg)
            NSLog("HaloNotch Alexa: \(msg)")
        }
    }

    // MARK: - CoreAudio helpers

    private func defaultOutputIsEcho(_ dev: IOBluetoothDevice) -> Bool {
        guard let current = Self.defaultOutput(),
              let target = Self.audioOutput(matchingName: dev.name ?? "", address: dev.addressString ?? "")
        else { return false }
        return current == target
    }

    private static func defaultOutput() -> AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return err == noErr ? id : nil
    }

    private static func setDefaultOutput(_ id: AudioDeviceID) {
        var dev = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
            var addr = AudioObjectPropertyAddress(mSelector: selector,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &dev)
        }
    }

    /// Find the output device for a Bluetooth speaker. Bluetooth audio UIDs embed
    /// the MAC address ("AA-BB-CC-DD-EE-FF:output"); fall back to the name.
    private static func audioOutput(matchingName name: String, address: String) -> AudioDeviceID? {
        let addrKey = address.lowercased().replacingOccurrences(of: ":", with: "-")
        var byName: AudioDeviceID?
        for id in allDevices() where hasOutput(id) {
            let uid = (stringProp(id, kAudioDevicePropertyDeviceUID) ?? "").lowercased()
                .replacingOccurrences(of: ":", with: "-")
            if !addrKey.isEmpty, uid.contains(addrKey) { return id }
            if !name.isEmpty, stringProp(id, kAudioObjectPropertyName) == name { byName = id }
        }
        return byName
    }

    private static func allDevices() -> [AudioDeviceID] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr
        else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr
        else { return [] }
        return ids
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                              mScope: kAudioDevicePropertyScopeOutput,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buf.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, buf) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(buf.assumingMemoryBound(to: AudioBufferList.self))
        return list.contains { $0.mNumberChannels > 0 }
    }

    private static func stringProp(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: selector,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr,
              let s = value?.takeRetainedValue() else { return nil }
        return s as String
    }
}

// MARK: - Pairing (inquiry + pair delegates)

extension AlexaSpeaker: IOBluetoothDeviceInquiryDelegate, IOBluetoothDevicePairDelegate {
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        tryPair(device)
    }

    func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32) {
        tryPair(device)
    }

    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        inquiry = nil
        if pairing == nil, status == .searching {
            fail("No Echo found. Say \"Alexa, pair Bluetooth\" and try again.")
        }
    }

    private func tryPair(_ device: IOBluetoothDevice?) {
        guard pairing == nil, let device, matches(device.name) else { return }
        inquiry?.stop()
        deviceName = device.name
        let p = IOBluetoothDevicePair(device: device)
        p?.delegate = self
        pairing = p
        if p?.start() != kIOReturnSuccess {
            pairing = nil
            fail("Pairing with \(device.name ?? "Echo") failed to start.")
        }
    }

    func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        pairing = nil
        if error == kIOReturnSuccess {
            status = .idle
            connectAndPlay()
        } else {
            fail("Pairing failed (\(error)). Say \"Alexa, pair Bluetooth\" and retry.")
        }
    }
}

// MARK: - Tray button

/// Speaker button that sits next to the transport controls.
struct AlexaButton: View {
    @ObservedObject private var alexa = AlexaSpeaker.shared
    @State private var pulse = false

    var body: some View {
        Button(action: { alexa.toggle() }) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .opacity(busy && pulse ? 0.35 : 1)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onAppear { alexa.refresh() }
        .onChange(of: busy) { _, b in
            if b {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                withAnimation(.default) { pulse = false }
            }
        }
    }

    private var busy: Bool { alexa.status == .connecting || alexa.status == .searching }

    private var symbol: String {
        switch alexa.status {
        case .connected: return "hifispeaker.fill"
        case .failed: return "exclamationmark.triangle"
        default: return "hifispeaker"
        }
    }

    private var tint: Color {
        switch alexa.status {
        case .connected: return Color(red: 0.0, green: 0.78, blue: 0.95)   // Alexa-ring cyan
        case .failed: return .orange
        default: return .white.opacity(0.7)
        }
    }

    private var help: String {
        let name = alexa.deviceName ?? "Echo"
        switch alexa.status {
        case .notPaired: return "Play on Alexa: say \"Alexa, pair Bluetooth\", then click to pair"
        case .idle: return "Play on \(name)"
        case .searching: return "Looking for an Echo in pairing mode…"
        case .connecting: return "Connecting to \(name)…"
        case .connected: return "Playing on \(name). Click to switch back to the Mac"
        case .failed(let msg): return msg + " Click to retry."
        }
    }
}
