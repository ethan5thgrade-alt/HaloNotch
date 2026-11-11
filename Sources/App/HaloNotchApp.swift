import SwiftUI

@main
struct HaloNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar item: the only "window" chrome the user sees. The notch panel
        // itself is an AppKit NSPanel managed by the AppDelegate.
        MenuBarExtra("HaloNotch", systemImage: "rectangle.tophalf.inset.filled") {
            MenuBarMenu()
                .environmentObject(Preferences.shared)
                .environmentObject(PomodoroController.shared)
        }

        Settings {
            SettingsView()
                .environmentObject(Preferences.shared)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders: guarantee no Dock icon even if Info.plist is stale.
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController()
        controller.show()
        windowController = controller

        // Kick off the services the enabled modules depend on.
        let prefs = Preferences.shared
        if prefs.moduleNowPlaying { NowPlayingController.shared.start() }
        if prefs.moduleBattery    { BatteryService.shared.start() }
        if prefs.moduleSchool     { ScheduleService.shared.start(); HomeworkService.shared.start() }
        AlexaSpeaker.shared.startObserving()

        // Dev aid: `open HaloNotch.app --args --demo-open` expands the tray on
        // launch so the expanded UI can be screenshotted without hovering.
        if CommandLine.arguments.contains("--demo-open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(prefs.openAnimation) { NotchState.shared.mode = .open }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NowPlayingController.shared.stop()
        BatteryService.shared.stop()
        ScheduleService.shared.stop()
        HomeworkService.shared.stop()
    }
}
