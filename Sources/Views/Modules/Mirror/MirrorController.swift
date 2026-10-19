import AVFoundation
import Combine

/// Owns the camera capture session for "mirror mode". The session only runs
/// while the mirror is on screen — `start()` when the button is tapped,
/// `stop()` when it's dismissed or the tray closes — so the camera (and its
/// green privacy light) is never live in the background.
final class MirrorController: ObservableObject {
    static let shared = MirrorController()

    let session = AVCaptureSession()
    /// Bound to the session once, here, before it can ever be running. The
    /// view only hosts this layer — re-binding a preview layer on the main
    /// thread while `startRunning()` is enumerating connections on `queue`
    /// throws (collection mutated while enumerated) and aborts the app.
    let previewLayer: AVCaptureVideoPreviewLayer

    enum Status { case idle, live, denied, unavailable }
    @Published private(set) var status: Status = .idle

    private let queue = DispatchQueue(label: "com.ethanstrauss.halonotch.mirror")
    private var configured = false

    private init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.run() } else { self?.set(.denied) }
            }
        case .denied, .restricted:
            set(.denied)
        @unknown default:
            set(.denied)
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        set(.idle)
    }

    private func run() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(for: .video)
                guard let device,
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    self.set(.unavailable)
                    return
                }
                self.session.addInput(input)
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            self.set(.live)
        }
    }

    /// Push a status change onto the main thread (Published updates must be).
    private func set(_ s: Status) {
        if Thread.isMainThread { status = s }
        else { DispatchQueue.main.async { self.status = s } }
    }
}
