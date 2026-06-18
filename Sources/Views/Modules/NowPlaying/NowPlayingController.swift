import SwiftUI
import Combine

/// Layers the two now-playing sources: AppleScript (always on, Spotify/Music)
/// and the universal MediaRemote adapter (when installed). Picks the best
/// snapshot, advances the scrubber between updates, and routes transport
/// controls to whichever backend can actually drive the active app.
final class NowPlayingController: ObservableObject {
    static let shared = NowPlayingController()

    @Published private(set) var info = NowPlayingInfo()
    @Published private(set) var activeSourceName = ""

    private let appleScript = AppleScriptSource()
    private let adapter = MediaRemoteAdapterSource()
    private var latest: [String: NowPlayingInfo] = [:]
    private var started = false
    private var tick: Timer?
    private var baseElapsed: Double = 0
    private var baseTime = Date()

    private init() {}

    /// Live elapsed time, advanced locally so the scrubber moves smoothly.
    var currentElapsed: Double {
        guard info.isPlaying, info.duration > 0 else { return min(info.elapsed, info.duration) }
        return min(baseElapsed + Date().timeIntervalSince(baseTime), info.duration)
    }

    var hasAdapter: Bool { adapter.isAvailable }

    func start() {
        guard !started else { return }
        started = true
        let prefs = Preferences.shared

        if prefs.nowPlayingSource != .adapter {
            appleScript.start { [weak self] in self?.ingest($0, from: "applescript") }
        }
        if prefs.nowPlayingSource != .appleScript, adapter.isAvailable {
            adapter.start { [weak self] in self?.ingest($0, from: "adapter") }
        }

        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.info.isPlaying else { return }
            self.objectWillChange.send()   // refresh the scrubber
        }
    }

    func stop() {
        appleScript.stop()
        adapter.stop()
        tick?.invalidate(); tick = nil
        latest.removeAll()
        started = false
    }

    func restart() { stop(); start() }

    // MARK: - Merge

    private func ingest(_ newInfo: NowPlayingInfo, from source: String) {
        latest[source] = newInfo
        recompute()
    }

    private func recompute() {
        func score(_ source: String, _ i: NowPlayingInfo) -> Int {
            (i.isPlaying ? 100 : 0) + (source == "adapter" ? 10 : 0)
        }
        let best = latest
            .filter { $0.value.hasContent }
            .max { score($0.key, $0.value) < score($1.key, $1.value) }

        if let best {
            let chosen = best.value
            // Reset the local scrubber clock whenever the snapshot meaningfully changes.
            if chosen.title != info.title || abs(chosen.elapsed - currentElapsed) > 2 || chosen.isPlaying != info.isPlaying {
                baseElapsed = chosen.elapsed
                baseTime = Date()
            }
            info = chosen
            activeSourceName = best.key == "adapter" ? adapter.name : appleScript.name
        } else {
            info = NowPlayingInfo()
            activeSourceName = ""
        }
    }

    // MARK: - Controls

    func togglePlayPause() {
        route { $0.playPause(self.info) }
        info.isPlaying.toggle()        // optimistic; corrected on next poll
        baseElapsed = currentElapsed
        baseTime = Date()
    }
    func next()     { route { $0.next(self.info) } }
    func previous() { route { $0.previous(self.info) } }

    private func route(_ action: (NowPlayingSource) -> Void) {
        if info.isScriptable {
            action(appleScript)            // reliable for Spotify / Music
        } else if adapter.isAvailable {
            action(adapter)                // best-effort universal control
        } else {
            action(appleScript)
        }
    }
}
