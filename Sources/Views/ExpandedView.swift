import SwiftUI

/// The glass tray that drops below the notch when open. Background honors the
/// material preference; content honors the enabled-module toggles.
struct ExpandedPanel: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var state: NotchState
    @EnvironmentObject var mirror: MirrorController

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if state.mirrorMode {
                    MirrorView()
                } else {
                    ExpandedContent().padding(14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            mirrorToggle
        }
        .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
    }

    /// Floating button: enter the mirror, or exit back to the modules.
    private var mirrorToggle: some View {
        Button(action: toggleMirror) {
            Image(systemName: state.mirrorMode ? "xmark" : "camera.viewfinder")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.45), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(12)
        .help(state.mirrorMode ? "Close mirror" : "Mirror")
    }

    private func toggleMirror() {
        state.mirrorMode.toggle()
        if state.mirrorMode { mirror.start() } else { mirror.stop() }
    }

    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        switch prefs.material {
        case .black:
            shape.fill(Color.black)
                .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
        case .glass, .auto:
            // Native glass + a faint "smoked" tint so white content stays
            // legible over bright backgrounds, without killing the translucency.
            GlassSurface(cornerRadius: 24)
                .overlay(shape.fill(.black.opacity(0.18)))
        }
    }
}

private struct ExpandedContent: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var np: NowPlayingController

    private var hasSidebar: Bool {
        prefs.moduleClock || prefs.moduleBattery || prefs.moduleTimer || prefs.moduleSchool
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if prefs.moduleNowPlaying {
                NowPlayingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if hasSidebar {
                if prefs.moduleNowPlaying {
                    Divider().overlay(Color.white.opacity(0.12))
                }
                VStack(alignment: .leading, spacing: 10) {
                    if prefs.moduleSchool  { SchoolView() }
                    if prefs.moduleClock   { ClockCalendarView() }
                    if prefs.moduleBattery { BatteryView() }
                    if prefs.moduleTimer   { TimerView() }
                    Spacer(minLength: 0)
                }
                .frame(width: prefs.moduleNowPlaying ? 224 : 380)
            }

            if !prefs.moduleNowPlaying && !hasSidebar {
                Text("All modules are off — enable some in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(.white)
    }
}
