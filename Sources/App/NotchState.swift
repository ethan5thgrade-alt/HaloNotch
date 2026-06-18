import SwiftUI

/// Live UI state for the notch. Drives the open/closed morph and which content
/// shows. Geometry is pushed in from `ScreenGeometry` by the window controller.
final class NotchState: ObservableObject {
    static let shared = NotchState()

    enum Mode: Equatable {
        case closed   // just the notch strip (+ any compact live activity)
        case open     // expanded panel dropped below the notch
    }

    @Published var mode: Mode = .closed
    @Published var isHovering = false

    /// Size of the physical (or synthesized) notch in points.
    @Published var notchSize = CGSize(width: 200, height: 32)
    /// Size of the expanded panel that drops below the notch.
    @Published var expandedSize = CGSize(width: 640, height: 190)
    /// True when we're hugging a real hardware notch (vs a floating pill).
    @Published var hasPhysicalNotch = true

    private init() {}

    func open()  { if mode != .open  { mode = .open  } }
    func close() { if mode != .closed { mode = .closed; isHovering = false } }

    /// The full bounds the hosting view needs: wide and tall enough for the
    /// expanded panel, with the notch centered at the top.
    var contentSize: CGSize {
        CGSize(width: max(expandedSize.width, notchSize.width) + 40,
               height: expandedSize.height + notchSize.height + 24)
    }
}
