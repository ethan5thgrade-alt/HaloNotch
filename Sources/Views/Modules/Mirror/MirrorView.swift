import AVFoundation
import AppKit
import SwiftUI

/// Fills the tray with a live camera feed, flipped horizontally so it reads
/// like a real mirror. The camera sits behind the notch, so this is literally
/// a mirror in the notch.
struct MirrorView: View {
    @EnvironmentObject var mirror: MirrorController

    var body: some View {
        ZStack {
            Color.black
            switch mirror.status {
            case .live, .idle:
                CameraPreview(previewLayer: mirror.previewLayer)
                    .scaleEffect(x: -1, y: 1)   // horizontal flip = mirror
            case .denied:
                message("video.slash.fill", "Camera access denied",
                        "Turn it on in System Settings › Privacy & Security › Camera.")
            case .unavailable:
                message("video.slash.fill", "No camera found",
                        "Couldn’t open the built-in camera.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func message(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(.white.opacity(0.7))
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }
}

/// AppKit bridge that hosts the controller's `AVCaptureVideoPreviewLayer`.
/// It never touches the session itself — see `MirrorController.previewLayer`.
struct CameraPreview: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(previewLayer: previewLayer)
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {}

    final class PreviewNSView: NSView {
        let previewLayer: AVCaptureVideoPreviewLayer

        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            wantsLayer = true
            // The shared layer may still sit in a previous (dismissed) view.
            previewLayer.removeFromSuperlayer()
            layer?.addSublayer(previewLayer)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}
