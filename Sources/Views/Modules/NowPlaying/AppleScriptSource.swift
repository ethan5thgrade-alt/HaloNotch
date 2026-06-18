import AppKit

/// Reads & controls Spotify and Apple Music via AppleScript. Public, no private
/// frameworks, never breaks — but limited to those two apps. This is the
/// always-on baseline source.
final class AppleScriptSource: NowPlayingSource {
    let name = "AppleScript (Spotify / Music)"
    var isAvailable: Bool { true }

    private var timer: Timer?
    private var onUpdate: ((NowPlayingInfo) -> Void)?
    private let queue = DispatchQueue(label: "halonotch.applescript")
    private var lastArtworkKey = ""
    private var cachedArtwork: NSImage?

    func start(onUpdate: @escaping (NowPlayingInfo) -> Void) {
        self.onUpdate = onUpdate
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        queue.async { [weak self] in
            guard let self else { return }
            let raw = Self.run(Self.stateScript) ?? ""
            var info = self.parse(raw)
            if info.hasContent, info.artworkKey != self.lastArtworkKey {
                info.artwork = self.fetchArtwork(for: info)
                self.lastArtworkKey = info.artworkKey
                self.cachedArtwork = info.artwork
            } else if info.hasContent {
                info.artwork = self.cachedArtwork
            }
            DispatchQueue.main.async { self.onUpdate?(info) }
        }
    }

    private func parse(_ raw: String) -> NowPlayingInfo {
        let lines = raw.components(separatedBy: "\n")
        var candidates: [NowPlayingInfo] = []
        for line in lines where !line.isEmpty {
            let f = line.components(separatedBy: "\t")
            guard f.count >= 7 else { continue }
            var i = NowPlayingInfo()
            i.appName = f[0]
            i.isPlaying = f[1].lowercased().contains("playing")
            i.title = f[2]
            i.artist = f[3]
            i.album = f[4]
            i.duration = Double(f[5]) ?? 0
            i.elapsed = Double(f[6]) ?? 0
            i.artworkKey = "\(f[0])|\(f[2])|\(f[3])"
            if !i.title.isEmpty { candidates.append(i) }
        }
        // Prefer a playing source, then any with content.
        return candidates.first(where: { $0.isPlaying }) ?? candidates.first ?? NowPlayingInfo()
    }

    private func fetchArtwork(for info: NowPlayingInfo) -> NSImage? {
        guard info.appName == "Spotify" else { return nil }  // Music artwork is binary; skip in v1
        guard let urlString = Self.run(Self.spotifyArtworkScript),
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Controls (target whichever app is active)

    func playPause(_ info: NowPlayingInfo) { control("playpause", info) }
    func next(_ info: NowPlayingInfo)      { control("next track", info) }
    func previous(_ info: NowPlayingInfo)  { control("previous track", info) }

    private func control(_ command: String, _ info: NowPlayingInfo) {
        let app = info.appName.isEmpty ? "Spotify" : info.appName
        queue.async { _ = Self.run("tell application \"\(app)\" to \(command)") }
    }

    // MARK: - AppleScript plumbing

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }

    /// Returns one tab-separated line per running player (Spotify, then Music).
    private static let stateScript = """
    set spotifyLine to ""
    set musicLine to ""
    if application "Spotify" is running then
        try
            tell application "Spotify"
                set spotifyLine to "Spotify" & tab & (player state as text) & tab & (name of current track) & tab & (artist of current track) & tab & (album of current track) & tab & ((duration of current track) / 1000 as text) & tab & (player position as text)
            end tell
        end try
    end if
    if application "Music" is running then
        try
            tell application "Music"
                set musicLine to "Music" & tab & (player state as text) & tab & (name of current track) & tab & (artist of current track) & tab & (album of current track) & tab & (duration of current track as text) & tab & (player position as text)
            end tell
        end try
    end if
    return spotifyLine & linefeed & musicLine
    """

    private static let spotifyArtworkScript = """
    if application "Spotify" is running then
        try
            tell application "Spotify" to return artwork url of current track
        end try
    end if
    return ""
    """
}
