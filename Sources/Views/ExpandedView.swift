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
                } else if state.schoolMode {
                    SchoolPanel().padding(14)
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

    /// Floating buttons: school panel and mirror, or exit back to the modules.
    private var mirrorToggle: some View {
        HStack(spacing: 6) {
            if state.schoolMode {
                Button(action: openHomeworkHelper) {
                    trayButtonLabel("arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                .help("Open Homework Helper")
            }
            if !state.mirrorMode {
                Button(action: { state.schoolMode.toggle() }) {
                    trayButtonLabel(state.schoolMode ? "xmark" : "graduationcap.fill")
                }
                .buttonStyle(.plain)
                .help(state.schoolMode ? "Close school" : "School")
            }
            if !state.schoolMode {
                Button(action: toggleMirror) {
                    trayButtonLabel(state.mirrorMode ? "xmark" : "camera.viewfinder")
                }
                .buttonStyle(.plain)
                .help(state.mirrorMode ? "Close mirror" : "Mirror")
            }
        }
        .padding(12)
    }

    private func trayButtonLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(.black.opacity(0.45), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }

    /// Open the Homework Helper Mac app (falls back to the browser if it's
    /// missing), then tuck the tray away — the app is now the focus.
    private func openHomeworkHelper() {
        let app = URL(fileURLWithPath: "/Applications/Homework Helper.app")
        if FileManager.default.fileExists(atPath: app.path) {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        } else if let url = URL(string: "http://localhost:8788/") {
            NSWorkspace.shared.open(url)
        }
        state.close()
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
        prefs.moduleClock || prefs.moduleBattery || prefs.moduleTimer
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
