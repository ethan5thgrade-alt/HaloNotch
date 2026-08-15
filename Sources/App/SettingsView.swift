import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prefs: Preferences

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)

                Picker("Open the notch on", selection: $prefs.openOnHover) {
                    Text("Hover").tag(true)
                    Text("Click").tag(false)
                }

                VStack(alignment: .leading) {
                    Text("Animation speed")
                    HStack {
                        Text("Snappy").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $prefs.animationSpeed, in: 0.5...1.5)
                        Text("Smooth").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Appearance") {
                Picker("Tray material", selection: $prefs.material) {
                    ForEach(NotchMaterial.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text("The strip hugging the notch is always solid black so it merges with the hardware. This controls the panel that drops below it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Now Playing") {
                Picker("Source", selection: $prefs.nowPlayingSource) {
                    ForEach(NowPlayingSourceKind.allCases) { Text($0.label).tag($0) }
                }
                .onChange(of: prefs.nowPlayingSource) { _, _ in NowPlayingController.shared.restart() }

                Toggle("Show audio visualizer", isOn: $prefs.showVisualizer)

                HStack(spacing: 6) {
                    Image(systemName: NowPlayingController.shared.hasAdapter ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(NowPlayingController.shared.hasAdapter ? .green : .secondary)
                    Text(NowPlayingController.shared.hasAdapter
                         ? "Universal adapter installed — every app's media works."
                         : "Universal adapter not installed. Spotify & Apple Music work now; run scripts/install-mediaremote-adapter.sh to cover every app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Modules") {
                Toggle("Now Playing", isOn: $prefs.moduleNowPlaying)
                    .onChange(of: prefs.moduleNowPlaying) { _, on in
                        on ? NowPlayingController.shared.start() : NowPlayingController.shared.stop()
                    }
                Toggle("Battery & charging", isOn: $prefs.moduleBattery)
                    .onChange(of: prefs.moduleBattery) { _, on in
                        on ? BatteryService.shared.start() : BatteryService.shared.stop()
                    }
                Toggle("Clock & calendar", isOn: $prefs.moduleClock)
                Toggle("Timer / Pomodoro", isOn: $prefs.moduleTimer)
                Toggle("School schedule", isOn: $prefs.moduleSchool)
                    .onChange(of: prefs.moduleSchool) { _, on in
                        if on { ScheduleService.shared.start() } else { ScheduleService.shared.stop() }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 560)
    }
}
