import AppKit
import SwiftUI

/// Owns the floating panel, positions it over the notch, hosts the SwiftUI
/// content, and turns cursor movement into open/close transitions.
final class NotchWindowController {
    private var panel: NotchPanel?
    private let hover = HoverMonitor()
    private let state = NotchState.shared
    private let prefs = Preferences.shared
    private var geo = ScreenGeometry.measure()

    func show() {
        rebuild()
        hover.onMouseMove = { [weak self] p in self?.handleMove(p) }
        hover.onMouseDown = { [weak self] p in self?.handleDown(p) }
        hover.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func screensChanged() { rebuild() }

    private func rebuild() {
        geo = ScreenGeometry.measure(extraWidthPadding: CGFloat(prefs.notchWidthPadding))
        state.notchSize = geo.notchSize
        state.hasPhysicalNotch = geo.hasPhysicalNotch

        let size = state.contentSize
        let origin = CGPoint(x: geo.screen.frame.midX - size.width / 2,
                             y: geo.screen.frame.maxY - size.height)
        let frame = CGRect(origin: origin, size: size)

        if let panel {
            panel.setFrame(frame, display: true)
            return
        }

        let panel = NotchPanel(contentRect: frame)
        let root = NotchRootView()
            .environmentObject(prefs)
            .environmentObject(state)
            .environmentObject(NowPlayingController.shared)
            .environmentObject(BatteryService.shared)
            .environmentObject(CalendarService.shared)
            .environmentObject(PomodoroController.shared)
            .environmentObject(MirrorController.shared)

        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        host.sizingOptions = []   // let our explicit frame win over intrinsic size
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel
    }

    // MARK: - Hit regions (global, bottom-left-origin screen coordinates)

    private var notchHoverRect: CGRect {
        let s = geo.screen.frame, n = state.notchSize
        return CGRect(x: s.midX - n.width / 2 - 8, y: s.maxY - n.height - 8,
                      width: n.width + 16, height: n.height + 8)
    }

    private var openRect: CGRect {
        let s = geo.screen.frame, n = state.notchSize, e = state.expandedSize
        let h = n.height + e.height
        return CGRect(x: s.midX - e.width / 2, y: s.maxY - h, width: e.width, height: h)
    }

    // MARK: - Open / close

    private func handleMove(_ p: CGPoint) {
        if state.mode == .closed {
            if prefs.openOnHover && notchHoverRect.contains(p) { open() }
        } else {
            // close once the cursor leaves the panel (with a little grace margin)
            if !openRect.insetBy(dx: -16, dy: -16).contains(p) { close() }
        }
    }

    private func handleDown(_ p: CGPoint) {
        if state.mode == .closed && !prefs.openOnHover && notchHoverRect.contains(p) { open() }
    }

    private func open() {
        panel?.ignoresMouseEvents = false
        withAnimation(prefs.openAnimation) {
            state.mode = .open
            state.isHovering = true
        }
    }

    private func close() {
        // Closing the tray always exits the mirror and stops the camera.
        if state.mirrorMode {
            state.mirrorMode = false
            MirrorController.shared.stop()
        }
        withAnimation(prefs.closeAnimation) {
            state.mode = .closed
            state.isHovering = false
        }
        // Restore click-through only after the collapse animation finishes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.state.mode == .closed else { return }
            self.panel?.ignoresMouseEvents = true
        }
    }
}
