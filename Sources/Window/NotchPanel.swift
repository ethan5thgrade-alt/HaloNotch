import AppKit

/// A borderless, transparent, non-activating panel that floats above the menu
/// bar so it can draw over and around the notch.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        // Above the menu bar so the notch strip draws over the system black area.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        isMovable = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true

        // Start click-through; the controller flips this on when expanded.
        ignoresMouseEvents = true
    }

    // Allow controls to receive clicks, but never steal focus / become main.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
