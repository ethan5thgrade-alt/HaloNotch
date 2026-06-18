import AppKit

/// Watches the cursor everywhere (not just inside our window) so we can expand
/// the notch on hover even though the app is never the active app. Global
/// monitors observe events bound for *other* apps; the local monitor covers the
/// case where our panel is key. Mouse-move monitoring needs no special
/// permission (unlike global keyboard monitoring).
final class HoverMonitor {
    private var global: Any?
    private var local: Any?

    var onMouseMove: ((CGPoint) -> Void)?
    var onMouseDown: ((CGPoint) -> Void)?

    func start() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown]
        global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.dispatch(event)
        }
        local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.dispatch(event)
            return event
        }
    }

    private func dispatch(_ event: NSEvent) {
        let p = NSEvent.mouseLocation   // global, bottom-left origin — matches NSScreen.frame
        switch event.type {
        case .mouseMoved:    onMouseMove?(p)
        case .leftMouseDown: onMouseDown?(p)
        default: break
        }
    }

    func stop() {
        if let g = global { NSEvent.removeMonitor(g) }
        if let l = local { NSEvent.removeMonitor(l) }
        global = nil
        local = nil
    }

    deinit { stop() }
}
