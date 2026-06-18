import AppKit

/// Everything we need to know about where the notch is on a given screen.
struct NotchGeometry {
    let screen: NSScreen
    let notchSize: CGSize
    let hasPhysicalNotch: Bool
    /// The notch strip in global (bottom-left origin) screen coordinates.
    let notchFrame: CGRect
}

enum ScreenGeometry {
    /// Default pill size used on Macs with no physical notch.
    static let syntheticNotch = CGSize(width: 200, height: 32)

    /// Pick the best screen and measure its notch. Prefers a screen that
    /// actually has a notch; falls back to the main screen with a synthesized pill.
    static func measure(extraWidthPadding: CGFloat = 0) -> NotchGeometry {
        let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        let screen = notched ?? NSScreen.main ?? NSScreen.screens.first!
        let hasNotch = screen.safeAreaInsets.top > 0

        let notchSize: CGSize
        if hasNotch {
            let height = screen.safeAreaInsets.top
            var width = syntheticNotch.width
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                let measured = screen.frame.width - left.width - right.width
                if measured > 60 { width = measured }   // sanity guard
            }
            notchSize = CGSize(width: width, height: height)
        } else {
            notchSize = CGSize(width: syntheticNotch.width + extraWidthPadding * 2,
                               height: syntheticNotch.height)
        }

        let f = screen.frame
        let notchFrame = CGRect(x: f.midX - notchSize.width / 2,
                                y: f.maxY - notchSize.height,
                                width: notchSize.width,
                                height: notchSize.height)

        return NotchGeometry(screen: screen,
                             notchSize: notchSize,
                             hasPhysicalNotch: hasNotch,
                             notchFrame: notchFrame)
    }
}
