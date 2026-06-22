import SwiftUI

/// The playable media "skin" for Now Playing. Tap the disc to cycle.
enum RecordSkin: String, CaseIterable, Identifiable {
    case vinyl, cassette, cd
    var id: String { rawValue }
    var label: String {
        switch self {
        case .vinyl:    return "Vinyl"
        case .cassette: return "Cassette"
        case .cd:       return "CD"
        }
    }
    var next: RecordSkin {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Picks the active skin and lets a tap cycle to the next one. Drop-in
/// replacement for the bare `VinylRecord`.
struct NowPlayingMedia: View {
    let artwork: NSImage?
    let isPlaying: Bool
    @EnvironmentObject var prefs: Preferences

    var body: some View {
        Group {
            switch prefs.recordSkin {
            case .vinyl:    VinylRecord(artwork: artwork, isPlaying: isPlaying)
            case .cassette: CassetteTape(artwork: artwork, isPlaying: isPlaying)
            case .cd:       CDDisc(artwork: artwork, isPlaying: isPlaying)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                prefs.cycleRecordSkin()
            }
        }
        .help("Tap to switch: vinyl · cassette · CD")
    }
}

// MARK: - Reusable spin

/// Time-anchored continuous rotation: spins while `isPlaying`, banks the angle
/// on pause so resuming never jumps. Capped at 30fps; idle when paused.
private struct RecordSpin: ViewModifier {
    let isPlaying: Bool
    var degPerSec: Double = 75

    @State private var accumulated: Double = 0
    @State private var anchor: Date? = nil

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { ctx in
            content.rotationEffect(.degrees(angle(at: ctx.date)))
        }
        .onAppear { if isPlaying { anchor = Date() } }
        .onChange(of: isPlaying) { _, playing in
            if playing { anchor = Date() }
            else {
                if let a = anchor { accumulated += Date().timeIntervalSince(a) * degPerSec }
                anchor = nil
            }
        }
    }

    private func angle(at now: Date) -> Double {
        let live = isPlaying ? (anchor.map { now.timeIntervalSince($0) * degPerSec } ?? 0) : 0
        return (accumulated + live).truncatingRemainder(dividingBy: 360)
    }
}

extension View {
    func recordSpin(isPlaying: Bool, degPerSec: Double = 75) -> some View {
        modifier(RecordSpin(isPlaying: isPlaying, degPerSec: degPerSec))
    }
}

// MARK: - Cassette

/// A cassette tape: album art on the label, two reels that spin while playing.
struct CassetteTape: View {
    let artwork: NSImage?
    let isPlaying: Bool

    var body: some View {
        GeometryReader { geo in
            let cw = min(geo.size.width, geo.size.height * 1.55)
            let ch = cw / 1.55
            body(cw, ch)
                .frame(width: cw, height: ch)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func body(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: h * 0.10, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.11)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: h * 0.10, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

            VStack(spacing: h * 0.06) {
                // label band: album art + faux track lines
                HStack(spacing: w * 0.035) {
                    artThumb(h * 0.24)
                    VStack(alignment: .leading, spacing: h * 0.035) {
                        Capsule().fill(.black.opacity(0.55)).frame(width: w * 0.34, height: h * 0.045)
                        Capsule().fill(.black.opacity(0.4)).frame(width: w * 0.24, height: h * 0.04)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, w * 0.02)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, h * 0.04)
                .background(RoundedRectangle(cornerRadius: h * 0.05)
                    .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.78)],
                                         startPoint: .top, endPoint: .bottom)))

                // window with two spinning reels + tape
                ZStack {
                    RoundedRectangle(cornerRadius: h * 0.06).fill(Color.black.opacity(0.6))
                    Capsule().fill(Color(white: 0.25)).frame(height: h * 0.02)
                        .padding(.horizontal, w * 0.12).offset(y: -h * 0.07)
                    HStack(spacing: w * 0.16) {
                        reel(h * 0.24)
                        reel(h * 0.24)
                    }
                }
                .frame(height: h * 0.40)
                .padding(.horizontal, w * 0.04)

                // bottom drive holes
                HStack(spacing: w * 0.11) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle().fill(Color.black.opacity(0.5)).frame(width: h * 0.04, height: h * 0.04)
                    }
                }
            }
            .padding(.vertical, h * 0.08)
            .padding(.horizontal, w * 0.06)
        }
    }

    private func artThumb(_ s: CGFloat) -> some View {
        Group {
            if let artwork { Image(nsImage: artwork).resizable().scaledToFill() }
            else { Color.gray.overlay(Image(systemName: "music.note").foregroundStyle(.white)) }
        }
        .frame(width: s, height: s)
        .clipShape(RoundedRectangle(cornerRadius: s * 0.16, style: .continuous))
    }

    private func reel(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.06))
            Circle().fill(Color(white: 0.85)).frame(width: s * 0.52, height: s * 0.52)
                .overlay(teeth(s * 0.52))
                .recordSpin(isPlaying: isPlaying, degPerSec: 130)
        }
        .frame(width: s, height: s)
    }

    private func teeth(_ s: CGFloat) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.25))
                    .frame(width: s * 0.14, height: s * 0.46)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            Circle().fill(Color(white: 0.3)).frame(width: s * 0.26, height: s * 0.26)
        }
    }
}

// MARK: - CD

/// A compact disc: iridescent rainbow play-side that spins while playing.
struct CDDisc: View {
    let artwork: NSImage?
    let isPlaying: Bool

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            disc(d)
                .recordSpin(isPlaying: isPlaying, degPerSec: 95)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var rainbow: [Color] {
        ([.cyan, .blue, .purple, .pink, .red, .orange, .yellow, .green, .cyan] as [Color])
            .map { $0.opacity(0.5) }
    }

    private func disc(_ d: CGFloat) -> some View {
        ZStack {
            // iridescent body
            Circle().fill(AngularGradient(gradient: Gradient(colors: rainbow), center: .center))
                .overlay(Circle().fill(Color(white: 0.5).opacity(0.35)).blendMode(.overlay))
            // specular sweep
            Circle().fill(AngularGradient(
                gradient: Gradient(colors: [.white.opacity(0), .white.opacity(0.5),
                                            .white.opacity(0), .white.opacity(0.3), .white.opacity(0)]),
                center: .center))
                .blendMode(.plusLighter)
            // faint data tracks
            ForEach(0..<9, id: \.self) { i in
                Circle().stroke(.white.opacity(0.05), lineWidth: 0.5).padding(d * (0.07 + Double(i) * 0.038))
            }
            // clear inner ring
            Circle().fill(Color(white: 0.08))
                .frame(width: d * 0.36, height: d * 0.36)
                .overlay(Circle().fill(AngularGradient(gradient: Gradient(colors: rainbow), center: .center)).opacity(0.5))
            // metallic clamp ring
            Circle().fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d * 0.22, height: d * 0.22)
            // center hole
            Circle().fill(Color.black.opacity(0.85)).frame(width: d * 0.1, height: d * 0.1)
            Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1).frame(width: d * 0.22, height: d * 0.22)
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }
}
