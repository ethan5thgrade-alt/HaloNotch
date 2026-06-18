import SwiftUI

/// Bridges AppKit's translucent system material into SwiftUI. This is the
/// "fits with the rest of the computer" look on macOS 14–15 and a solid
/// fallback on 26.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.state = .active
    }
}

/// A rounded translucent surface. On macOS 26 (Tahoe) it uses the real native
/// Liquid Glass material so the panel matches the rest of the system chrome;
/// on earlier macOS it falls back to system vibrancy with a hairline rim.
struct GlassSurface: View {
    var cornerRadius: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
        } else {
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                )
                .overlay(
                    shape.strokeBorder(.black.opacity(0.25), lineWidth: 0.5)
                        .blendMode(.plusDarker)
                        .padding(0.5)
                )
        }
    }
}
