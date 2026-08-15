import SwiftUI

/// One unsubmitted assignment, scored for queue position.
struct HomeworkItem: Identifiable {
    let id: Int
    let name: String
    let course: String
    let points: Double?
    let due: Date?
    let missing: Bool
    /// points / days-until-due. Low = quick win, high = big and looming.
    let score: Double
}

/// Reads the Canvas data Locker already syncs to
/// ~/code/school-canvas/companion/data/state.json and publishes Ethan's
/// homework queue: easiest first, most important last (score ascending).
/// Polls the file's mtime every 60s, so a Locker sync shows up within a minute.
final class HomeworkService: ObservableObject {
    static let shared = HomeworkService()

    @Published private(set) var items: [HomeworkItem] = []

    private var timer: Timer?
    private var lastMTime: Date?
    private let stateURL = URL(fileURLWithPath: NSHomeDirectory() + "/code/school-canvas/companion/data/state.json")

    func start() {
        reload(force: true)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.reload(force: false)
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() { timer?.invalidate(); timer = nil }

    // MARK: - Locker's state.json (only the fields we need)

    private struct LockerState: Codable { let courses: [LockerCourse] }
    private struct LockerCourse: Codable { let name: String; let assignments: [LockerAsg] }
    private struct LockerAsg: Codable {
        let id: Int
        let name: String
        let due_at: String?
        let points: Double?
        let submitted: Bool
        let missing: Bool
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    private func reload(force: Bool) {
        let mtime = (try? FileManager.default.attributesOfItem(atPath: stateURL.path)[.modificationDate]) as? Date
        guard force || mtime != lastMTime else { return }
        lastMTime = mtime

        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(LockerState.self, from: data) else {
            DispatchQueue.main.async { self.items = [] }
            return
        }

        let now = Date()
        let horizon = now.addingTimeInterval(14 * 86400)
        var out: [HomeworkItem] = []
        for course in state.courses {
            let short = course.name.split(separator: "-").first.map(String.init) ?? course.name
            for a in course.assignments where !a.submitted {
                let due = a.due_at.flatMap { Self.iso.date(from: $0) }
                // Keep: missing work, or anything due in the next two weeks
                // (including up to 2 days past-due that isn't flagged yet).
                let recentPast = now.addingTimeInterval(-2 * 86400)
                guard a.missing || (due.map { $0 > recentPast && $0 < horizon } ?? false) else { continue }
                let daysLeft = max(due.map { $0.timeIntervalSince(now) / 86400 } ?? 0.5, 0.5)
                let score = (a.points ?? 5) / (a.missing ? 0.5 : daysLeft)
                out.append(HomeworkItem(id: a.id, name: a.name,
                                        course: short.trimmingCharacters(in: .whitespaces),
                                        points: a.points, due: due,
                                        missing: a.missing, score: score))
            }
        }
        let queue = Array(out.sorted { $0.score < $1.score }.prefix(6))
        DispatchQueue.main.async { self.items = queue }
    }
}
