import SwiftUI

/// The dropdown shown from the menu-bar status item.
struct MenuBarMenu: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var pomo: PomodoroController

    var body: some View {
        Group {
            SettingsLink { Text("HaloNotch Settings…") }
                .keyboardShortcut(",", modifiers: .command)

            Divider()

            Menu("Start Timer") {
                ForEach(pomo.presets, id: \.self) { minutes in
                    Button("\(minutes) minutes") {
                        pomo.setDuration(minutes: minutes)
                        pomo.start()
                    }
                }
            }
            if pomo.isActive {
                Button("Reset Timer") { pomo.reset() }
            }

            Divider()

            Toggle("Now Playing", isOn: $prefs.moduleNowPlaying)
            Toggle("Battery", isOn: $prefs.moduleBattery)
            Toggle("Clock & Calendar", isOn: $prefs.moduleClock)
            Toggle("Timer", isOn: $prefs.moduleTimer)

            Divider()

            Button("Quit HaloNotch") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}
