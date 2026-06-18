import AppKit

/// Universal now-playing for ANY app (browsers, podcast apps, etc.) on
/// macOS 15.4+ via the `ungive/mediaremote-adapter` trick: the system Perl
/// binary reports a `com.apple.*` bundle id, so it's allowed to load the
/// private MediaRemote framework that normal app bundles are now denied.
///
/// Resources are NOT bundled by default — run `scripts/install-mediaremote-adapter.sh`
/// to fetch/build them into Application Support. Until then `isAvailable` is
/// false and the controller falls back to AppleScript.
final class MediaRemoteAdapterSource: NowPlayingSource {
    let name = "MediaRemote adapter (universal)"

    private var process: Process?
    private var onUpdate: ((NowPlayingInfo) -> Void)?
    private var buffer = Data()
    private var artworkCache: [String: NSImage] = [:]

    var isAvailable: Bool { Self.adapterDir() != nil }

    static func adapterDir() -> URL? {
        let fm = FileManager.default
        func valid(_ dir: URL?) -> URL? {
            guard let dir else { return nil }
            return fm.fileExists(atPath: dir.appendingPathComponent("mediaremote-adapter.pl").path) ? dir : nil
        }
        if let bundled = valid(Bundle.main.resourceURL?.appendingPathComponent("mediaremote-adapter")) {
            return bundled
        }
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("HaloNotch/mediaremote-adapter")
        return valid(appSupport)
    }

    func start(onUpdate: @escaping (NowPlayingInfo) -> Void) {
        self.onUpdate = onUpdate
        guard let dir = Self.adapterDir() else { return }
        let script = dir.appendingPathComponent("mediaremote-adapter.pl")
        let framework = dir.appendingPathComponent("MediaRemoteAdapter.framework")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, framework.path, "stream"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()   // discard adapter chatter
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.ingest(handle.availableData)
        }
        do { try process.run(); self.process = process }
        catch { NSLog("HaloNotch: adapter failed to launch: \(error)") }
    }

    func stop() {
        process?.terminate()
        process = nil
        buffer.removeAll()
    }

    // MARK: - Stream parsing

    private func ingest(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            decode(line)
        }
    }

    private func decode(_ line: Data) {
        guard !line.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
        else { return }

        // Be tolerant of key-name variations between adapter versions.
        func str(_ keys: String...) -> String {
            for k in keys { if let v = obj[k] as? String { return v } }
            return ""
        }
        func num(_ keys: String...) -> Double {
            for k in keys {
                if let v = obj[k] as? Double { return v }
                if let v = obj[k] as? NSNumber { return v.doubleValue }
            }
            return 0
        }
        func boolean(_ keys: String...) -> Bool {
            for k in keys {
                if let v = obj[k] as? Bool { return v }
                if let v = obj[k] as? NSNumber { return v.boolValue }
            }
            return false
        }

        var info = NowPlayingInfo()
        info.title = str("title")
        info.artist = str("artist")
        info.album = str("album")
        info.bundleID = str("bundleIdentifier", "parentApplicationBundleIdentifier")
        info.appName = str("parentApplicationName", "appName")
        if info.appName.isEmpty { info.appName = appName(from: info.bundleID) }
        info.isPlaying = boolean("playing", "isPlaying") || num("playbackRate") > 0
        info.duration = num("duration")
        info.elapsed = num("elapsedTime", "elapsed")
        info.artworkKey = "\(info.bundleID)|\(info.title)|\(info.artist)"

        if let b64 = obj["artworkData"] as? String, !b64.isEmpty {
            if let cached = artworkCache[info.artworkKey] {
                info.artwork = cached
            } else if let data = Data(base64Encoded: b64), let image = NSImage(data: data) {
                artworkCache[info.artworkKey] = image
                info.artwork = image
            }
        } else {
            info.artwork = artworkCache[info.artworkKey]
        }

        guard info.hasContent else { return }
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(info) }
    }

    private func appName(from bundleID: String) -> String {
        guard !bundleID.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return "" }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    // MARK: - Controls (best-effort; only used for non-scriptable apps)

    func playPause(_ info: NowPlayingInfo) { send("togglePlayPause") }
    func next(_ info: NowPlayingInfo)      { send("nextTrack") }
    func previous(_ info: NowPlayingInfo)  { send("previousTrack") }

    private func send(_ command: String) {
        guard let dir = Self.adapterDir() else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [dir.appendingPathComponent("mediaremote-adapter.pl").path,
                             dir.appendingPathComponent("MediaRemoteAdapter.framework").path,
                             "send", command]
        try? process.run()
    }
}
