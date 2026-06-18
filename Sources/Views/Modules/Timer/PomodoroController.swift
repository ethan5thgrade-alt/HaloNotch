import SwiftUI
import Combine

/// A simple countdown / Pomodoro timer. When running it surfaces as a compact
/// live activity in the closed notch.
final class PomodoroController: ObservableObject {
    static let shared = PomodoroController()

    @Published private(set) var isRunning = false
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published var duration: TimeInterval = 25 * 60

    /// Quick-pick lengths (minutes) offered in the UI.
    let presets: [Int] = [5, 15, 25, 50]

    private var timer: Timer?
    private init() {}

    var progress: Double { duration > 0 ? max(0, 1 - remaining / duration) : 0 }
    var isActive: Bool { isRunning || remaining < duration }

    var label: String {
        let total = Int(remaining.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    func setDuration(minutes: Int) {
        duration = TimeInterval(minutes * 60)
        remaining = duration
    }

    func startPause() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        if remaining <= 0 { remaining = duration }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remaining = max(0, self.remaining - 1)
            if self.remaining == 0 { self.finish() }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate(); timer = nil
    }

    func reset() {
        pause()
        remaining = duration
    }

    private func finish() {
        pause()
        NSSound(named: "Glass")?.play()
    }
}
