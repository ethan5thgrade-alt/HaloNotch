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
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(np.info.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(np.info.artist.isEmpty ? np.info.album : np.info.artist)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                Spacer(minLength: 6)
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NowPlayingMedia(artwork: np.info.artwork, isPlaying: np.info.isPlaying)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: .infinity)
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
            transport("backward.fill", size: 15) { np.previous() }
            transport(np.info.isPlaying ? "pause.fill" : "play.fill", size: 22) { np.togglePlayPause() }
                .offset(x: 6)
            transport("forward.fill", size: 15) { np.next() }
                .offset(x: 12)
        }
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

/// A spinning vinyl record: the album art is the center label, ringed by
/// grooves, with a tonearm that drops on while playing. Rotates continuously
/// when playing and holds its angle when paused (time-anchored so pause/resume
/// never jumps).
struct VinylRecord: View {
    let artwork: NSImage?
    let isPlaying: Bool

    @State private var accumulated: Double = 0   // degrees banked while paused
    @State private var anchor: Date? = nil
    private let degPerSec: Double = 75           // ~1 revolution / 4.8s

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { ctx in
                    disc(d).rotationEffect(.degrees(angle(at: ctx.date)))
                }
                tonearm(d)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { if isPlaying { anchor = Date() } }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                anchor = Date()
            } else {
                if let a = anchor { accumulated += Date().timeIntervalSince(a) * degPerSec }
                anchor = nil
            }
        }
    }

    private func angle(at now: Date) -> Double {
        let live = isPlaying ? (anchor.map { now.timeIntervalSince($0) * degPerSec } ?? 0) : 0
        return (accumulated + live).truncatingRemainder(dividingBy: 360)
    }

    private func disc(_ d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.17), Color(white: 0.04)],
                                     center: .center, startRadius: d * 0.16, endRadius: d * 0.5))
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
                    .padding(d * (0.10 + Double(i) * 0.045))
            }
            // a sweeping sheen so the spin reads even on a dark disc
            Circle()
                .fill(AngularGradient(
                    gradient: Gradient(colors: [.white.opacity(0), .white.opacity(0.12),
                                                .white.opacity(0), .white.opacity(0.09), .white.opacity(0)]),
                    center: .center))
                .blendMode(.plusLighter)
            label(d * 0.5)
            Circle().fill(Color(white: 0.92)).frame(width: d * 0.028, height: d * 0.028)
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }

    private func label(_ s: CGFloat) -> some View {
        Group {
            if let artwork {
                Image(nsImage: artwork).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color.gray, Color.gray.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: s * 0.3)).foregroundStyle(.white.opacity(0.85)))
            }
        }
        .frame(width: s, height: s)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1))
    }

    private func tonearm(_ d: CGFloat) -> some View {
        VStack(spacing: 0) {
            // pivot bearing housing
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.93), Color(white: 0.55)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: d * 0.14, height: d * 0.14)
                Circle().fill(Color(white: 0.38)).frame(width: d * 0.055, height: d * 0.055)
            }
            // metallic arm tube
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.56)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: d * 0.026, height: d * 0.46)
            // headshell: collar + angled cartridge + finger-lift + stylus
            VStack(spacing: 0) {
                Rectangle().fill(Color(white: 0.5)).frame(width: d * 0.05, height: d * 0.022)
                RoundedRectangle(cornerRadius: d * 0.006, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.10)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: d * 0.095, height: d * 0.085)
                    .overlay(alignment: .topTrailing) {
                        Capsule().fill(Color(white: 0.58))
                            .frame(width: d * 0.05, height: d * 0.017)
                            .rotationEffect(.degrees(-32))
                            .offset(x: d * 0.022, y: -d * 0.004)
                    }
                Rectangle().fill(Color(white: 0.72)).frame(width: d * 0.007, height: d * 0.02)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 2.5, y: 1.5)
        .rotationEffect(.degrees(isPlaying ? 38 : 26), anchor: .top)
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: isPlaying)
        .offset(x: d * 0.34, y: -d * 0.36)
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
