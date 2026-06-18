import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var np: NowPlayingController
    @EnvironmentObject var prefs: Preferences

    var body: some View {
        if np.info.hasContent {
            playing
        } else {
            empty
        }
    }

    private var playing: some View {
        HStack(spacing: 12) {
            Artwork(image: np.info.artwork, size: 88, corner: 12)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(np.info.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text([np.info.artist, np.info.album].filter { !$0.isEmpty }.joined(separator: " — "))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)

                if prefs.showVisualizer {
                    Visualizer()
                        .frame(height: 16)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
                scrubber
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scrubber: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let frac = np.info.duration > 0 ? np.currentElapsed / np.info.duration : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(.white.opacity(0.9))
                        .frame(width: max(0, geo.size.width * frac))
                }
            }
            .frame(height: 4)

            HStack {
                Text(timeString(np.currentElapsed))
                Spacer()
                Text(timeString(np.info.duration))
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            Spacer()
            transport("backward.fill", size: 14) { np.previous() }
            transport(np.info.isPlaying ? "pause.fill" : "play.fill", size: 19) { np.togglePlayPause() }
            transport("forward.fill", size: 14) { np.next() }
            Spacer()
        }
        .padding(.top, 2)
    }

    private func transport(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.4))
            Text("Nothing playing")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// A multi-bar equalizer driven by a capped-framerate timeline. Pauses (and
/// stops consuming CPU) when nothing is playing.
struct Visualizer: View {
    @EnvironmentObject var np: NowPlayingController
    private let count = 28

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !np.info.isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = (geo.size.width - CGFloat(count - 1) * 2) / CGFloat(count)
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(0.85))
                            .frame(width: max(1, w), height: height(i, t, geo.size.height))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func height(_ i: Int, _ t: Double, _ maxH: CGFloat) -> CGFloat {
        guard np.info.isPlaying else { return 2 }
        let phase = Double(i) * 0.55
        let v = (sin(t * 7 + phase) * 0.5 + sin(t * 3.3 + phase * 1.7) * 0.5 + 1) / 2
        return 2 + CGFloat(max(0, min(1, v))) * (maxH - 2)
    }
}
