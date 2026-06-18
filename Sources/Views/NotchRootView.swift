import SwiftUI

/// Top-level content hosted inside the floating panel. Lays out three layers,
/// top-aligned and horizontally centered on the notch:
///   1. the glass tray that drops down when open,
///   2. the compact "live activity" flanks shown when closed,
///   3. the always-present black notch strip on top.
struct NotchRootView: View {
    @EnvironmentObject var state: NotchState
    @EnvironmentObject var prefs: Preferences

    var body: some View {
        let open = state.mode == .open
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 1) Glass tray — grows out from behind the notch.
                ExpandedPanel()
                    .frame(width: state.expandedSize.width, height: state.expandedSize.height)
                    .padding(.top, max(0, state.notchSize.height - 10))
                    .scaleEffect(open ? 1 : 0.86, anchor: .top)
                    .opacity(open ? 1 : 0)
                    .offset(y: open ? 0 : -14)
                    .allowsHitTesting(open)

                // 2) Compact flanks (music / timer) when closed.
                CompactView()
                    .opacity(open ? 0 : 1)
                    .allowsHitTesting(false)

                // 3) The black notch strip.
                NotchStrip(open: open)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The opaque black strip that hugs the physical notch so it merges with the
/// hardware. Stays black regardless of the glass setting.
private struct NotchStrip: View {
    @EnvironmentObject var state: NotchState
    var open: Bool

    var body: some View {
        NotchShape(topRadius: 10, bottomRadius: open ? 18 : 13)
            .fill(Color.black)
            .frame(width: state.notchSize.width, height: state.notchSize.height)
            .shadow(color: .black.opacity(open ? 0.4 : 0.0), radius: 10, y: 5)
    }
}

/// Compact live-activity content flanking the notch when closed.
private struct CompactView: View {
    @EnvironmentObject var state: NotchState
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var np: NowPlayingController
    @EnvironmentObject var pomo: PomodoroController

    private let flank: CGFloat = 72

    private var showMusic: Bool { prefs.moduleNowPlaying && np.info.hasContent }
    private var showTimer: Bool { prefs.moduleTimer && pomo.isRunning }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: flank, height: state.notchSize.height)
            Spacer(minLength: 0)
                .frame(width: state.notchSize.width)
            trailing
                .frame(width: flank, height: state.notchSize.height)
        }
        .frame(height: state.notchSize.height)
    }

    @ViewBuilder private var leading: some View {
        if showMusic {
            Artwork(image: np.info.artwork, size: state.notchSize.height - 8)
                .padding(.trailing, 6)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if showTimer {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
        }
    }

    @ViewBuilder private var trailing: some View {
        if showMusic && np.info.isPlaying {
            MiniVisualizer()
                .frame(width: 22, height: state.notchSize.height - 14)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if showTimer {
            Text(pomo.label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Reusable rounded album-art view with a music-note placeholder.
struct Artwork: View {
    let image: NSImage?
    var size: CGFloat
    var corner: CGFloat = 6

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").foregroundStyle(.white.opacity(0.8))
                        .font(.system(size: size * 0.42))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// A tiny animated equalizer used in the compact notch.
struct MiniVisualizer: View {
    @EnvironmentObject var np: NowPlayingController
    private let bars = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.09, paused: !np.info.isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule()
                        .fill(.white)
                        .frame(height: barHeight(i, t))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func barHeight(_ i: Int, _ t: Double) -> CGFloat {
        guard np.info.isPlaying else { return 3 }
        let phase = Double(i) * 1.3
        let v = (sin(t * 6 + phase) + 1) / 2          // 0…1
        return 3 + CGFloat(v) * 13
    }
}
