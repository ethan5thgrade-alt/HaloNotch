import AppKit

/// A normalized snapshot of what's currently playing, regardless of source.
struct NowPlayingInfo: Equatable {
    var title = ""
    var artist = ""
    var album = ""
    var appName = ""          // "Spotify", "Music", or a bundle-derived name
    var bundleID = ""
    var isPlaying = false
    var duration: Double = 0  // seconds
    var elapsed: Double = 0   // seconds, at the moment this snapshot was taken
    var artwork: NSImage?
    var artworkKey = ""       // cheap identity for artwork caching (track title/url)

    var hasContent: Bool { !title.isEmpty }

    /// Source app is one we can drive over AppleScript.
    var isScriptable: Bool {
        appName == "Spotify" || appName == "Music"
            || bundleID == "com.spotify.client" || bundleID == "com.apple.Music"
    }

    static func == (l: NowPlayingInfo, r: NowPlayingInfo) -> Bool {
        l.title == r.title && l.artist == r.artist && l.album == r.album
            && l.appName == r.appName && l.isPlaying == r.isPlaying
            && abs(l.duration - r.duration) < 0.5 && l.artworkKey == r.artworkKey
    }
}

/// A backend that can read (and sometimes control) now-playing state.
protocol NowPlayingSource: AnyObject {
    var name: String { get }
    var isAvailable: Bool { get }
    func start(onUpdate: @escaping (NowPlayingInfo) -> Void)
    func stop()
    func playPause(_ info: NowPlayingInfo)
    func next(_ info: NowPlayingInfo)
    func previous(_ info: NowPlayingInfo)
}
