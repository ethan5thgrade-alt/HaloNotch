import SwiftUI

/// A single class assignment for one period in one term (quarter).
struct SchoolClass: Codable {
    let period: Int
    let name: String
    let room: String
    let teacher: String
}

/// One timed block in a day template. `period` links it to a class; nil means
/// a fixed block like Royal Time or Lunch.
struct SchoolBlockDef: Codable {
    let label: String
    let period: Int?
    let start: String   // "8:30" (24h)
    let end: String
}

/// The whole school year. A default is written to
/// ~/Library/Application Support/HaloNotch/school.json on first run — edit that
/// file (then relaunch) to correct bell times or classes; it wins over the
/// compiled-in default.
struct SchoolConfig: Codable {
    let yearStart: String            // yyyy-MM-dd
    let yearEnd: String
    let termStarts: [String]         // first day of terms 1–4; flips course names
    let terms: [[SchoolClass]]       // outer index = term-1
    let days: [String: [SchoolBlockDef]]  // keyed mon/tue/wed/thu/fri
    let holidays: [String]           // yyyy-MM-dd, no school
    // Specific dates that run a different day template, keyed yyyy-MM-dd with
    // a `days` key as value (e.g. "2026-08-24": "fri" = no Royal Time that
    // Monday). Optional so older school.json files still decode.
    let dayOverrides: [String: String]?
}

/// A block resolved onto today's real clock, with its class attached.
struct ResolvedBlock: Identifiable {
    let id = UUID()
    let label: String
    let cls: SchoolClass?
    let start: Date
    let end: Date
}

enum SchoolPhase {
    case before          // school day, first bell not rung yet
    case during(Int)     // index into blocks
    case passing(Int)    // between blocks; index of the next one
    case after
}

/// Computes where Ethan is in the school day. 30s tick republishes so the
/// countdowns stay honest without a per-second timer.
final class ScheduleService: ObservableObject {
    static let shared = ScheduleService()

    @Published private(set) var blocks: [ResolvedBlock] = []
    @Published private(set) var phase: SchoolPhase = .after
    @Published private(set) var isSchoolDay = false
    @Published private(set) var offReason: String? = nil   // "Summer", "Weekend", …

    private var config: SchoolConfig = ScheduleService.defaultConfig
    private var timer: Timer?

    private let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    func start() {
        loadConfig()
        recompute()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.recompute()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() { timer?.invalidate(); timer = nil }

    // MARK: - Config

    private var configURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HaloNotch/school.json")
    }

    private func loadConfig() {
        let url = configURL
        if let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(SchoolConfig.self, from: data) {
            config = cfg
            return
        }
        // First run: persist the default so it's editable.
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(config) { try? data.write(to: url) }
    }

    // MARK: - Engine

    private func recompute() {
        let now = Date()
        let cal = Calendar.current

        guard let ys = dayFmt.date(from: config.yearStart),
              let ye = dayFmt.date(from: config.yearEnd),
              now >= ys, now <= cal.date(byAdding: .day, value: 1, to: ye) ?? ye else {
            publish([], .after, schoolDay: false, reason: "Summer")
            return
        }
        let todayKey = dayFmt.string(from: now)
        if config.holidays.contains(todayKey) {
            publish([], .after, schoolDay: false, reason: "No school today")
            return
        }
        let weekdayKeys = [1: "sun", 2: "mon", 3: "tue", 4: "wed", 5: "thu", 6: "fri", 7: "sat"]
        guard let weekdayKey = weekdayKeys[cal.component(.weekday, from: now)] else {
            publish([], .after, schoolDay: false, reason: "Weekend")
            return
        }
        let key = config.dayOverrides?[todayKey] ?? weekdayKey
        guard let template = config.days[key] else {
            publish([], .after, schoolDay: false, reason: "Weekend")
            return
        }

        // Which term are we in?
        let termIdx = config.termStarts.compactMap(dayFmt.date(from:)).lastIndex(where: { $0 <= now }) ?? 0
        let classes = config.terms.indices.contains(termIdx) ? config.terms[termIdx] : []
        let byPeriod = Dictionary(uniqueKeysWithValues: classes.map { ($0.period, $0) })

        let startOfDay = cal.startOfDay(for: now)
        func time(_ s: String) -> Date {
            let bits = s.split(separator: ":").compactMap { Int($0) }
            return cal.date(byAdding: .minute, value: (bits.first ?? 0) * 60 + (bits.count > 1 ? bits[1] : 0),
                            to: startOfDay) ?? startOfDay
        }
        let resolved = template.map { def in
            ResolvedBlock(label: def.label,
                          cls: def.period.flatMap { byPeriod[$0] },
                          start: time(def.start), end: time(def.end))
        }

        let phase: SchoolPhase
        if let i = resolved.firstIndex(where: { $0.start <= now && now < $0.end }) {
            phase = .during(i)
        } else if let i = resolved.firstIndex(where: { now < $0.start }) {
            phase = (i == 0) ? .before : .passing(i)
        } else {
            phase = .after
        }
        publish(resolved, phase, schoolDay: true, reason: nil)
    }

    private func publish(_ b: [ResolvedBlock], _ p: SchoolPhase, schoolDay: Bool, reason: String?) {
        DispatchQueue.main.async {
            self.blocks = b; self.phase = p
            self.isSchoolDay = schoolDay; self.offReason = reason
        }
    }

    // MARK: - Display helpers

    /// Show in the compact notch only when the info is actually live:
    /// a school day, from 45 min before first bell until last bell.
    var compactVisible: Bool {
        guard isSchoolDay, let first = blocks.first else { return false }
        switch phase {
        case .after: return false
        case .before: return Date() > first.start.addingTimeInterval(-45 * 60)
        default: return true
        }
    }

    /// Short label for the current/next block: "P2", "RT", "Lunch".
    var compactLead: String? {
        switch phase {
        case .during(let i): return shortLabel(blocks[i])
        case .passing(let i): return "→ " + shortLabel(blocks[i])
        case .before: return blocks.first.map(shortLabel)
        case .after: return nil
        }
    }

    /// Countdown / start time to pair with the lead.
    var compactTrail: String? {
        switch phase {
        case .during(let i): return "\(minutesLeft(blocks[i]))m"
        case .passing(let i): return Self.clockFmt.string(from: blocks[i].start)
        case .before: return blocks.first.map { Self.clockFmt.string(from: $0.start) }
        case .after: return nil
        }
    }

    func minutesLeft(_ b: ResolvedBlock) -> Int {
        max(0, Int(ceil(b.end.timeIntervalSince(Date()) / 60)))
    }

    private func shortLabel(_ b: ResolvedBlock) -> String {
        if b.label.hasPrefix("Period ") { return "P" + b.label.dropFirst(7) }
        if b.label == "Royal Time" { return "RT" }
        return b.label
    }

    static let clockFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm"; return f
    }()

    // MARK: - Ethan's 26/27 default
    // Bell times decoded from the school's posted schedule PDF (24-25 layout);
    // verify against week one and fix school.json if the school shifted them.
    static let defaultConfig = SchoolConfig(
        yearStart: "2026-08-19",
        yearEnd: "2027-06-09",
        termStarts: ["2026-08-19", "2026-10-19", "2027-02-01", "2027-04-12"],
        terms: [
            [ SchoolClass(period: 1, name: "FIN 100 SBCC", room: "B-3", teacher: "Oleson"),
              SchoolClass(period: 2, name: "AP Psychology", room: "I-2", teacher: "Hanes"),
              SchoolClass(period: 3, name: "Chemistry", room: "F-8", teacher: "Hardeman"),
              SchoolClass(period: 4, name: "English 10", room: "D-9", teacher: "Freund") ],
            [ SchoolClass(period: 1, name: "FIN 101 SBCC", room: "B-3", teacher: "Oleson"),
              SchoolClass(period: 2, name: "AP Psychology", room: "I-2", teacher: "Hanes"),
              SchoolClass(period: 3, name: "Chemistry", room: "F-8", teacher: "Hardeman"),
              SchoolClass(period: 4, name: "English 10", room: "D-9", teacher: "Freund") ],
            [ SchoolClass(period: 1, name: "Spanish 3", room: "E-7", teacher: "Heredia Rocha"),
              SchoolClass(period: 2, name: "World History", room: "I-8", teacher: "Gonzales"),
              SchoolClass(period: 3, name: "Math 3", room: "D-8", teacher: "Willis"),
              SchoolClass(period: 4, name: "Tennis", room: "GYM", teacher: "Carver") ],
            [ SchoolClass(period: 1, name: "Spanish 3", room: "E-7", teacher: "Heredia Rocha"),
              SchoolClass(period: 2, name: "World History", room: "I-8", teacher: "Gonzales"),
              SchoolClass(period: 3, name: "Math 3", room: "D-8", teacher: "Willis"),
              SchoolClass(period: 4, name: "Tennis", room: "GYM", teacher: "Carver") ],
        ],
        days: [
            // Mon/Wed: 8:30 start with Royal Time
            "mon": ScheduleService.royalDay, "wed": ScheduleService.royalDay,
            // Tue/Thu: late start (staff collab mornings)
            "tue": ScheduleService.lateDay, "thu": ScheduleService.lateDay,
            // Fri: long periods, no Royal Time
            "fri": [
                SchoolBlockDef(label: "Period 1", period: 1, start: "8:30", end: "10:01"),
                SchoolBlockDef(label: "Period 2", period: 2, start: "10:12", end: "11:44"),
                SchoolBlockDef(label: "Lunch", period: nil, start: "11:44", end: "12:19"),
                SchoolBlockDef(label: "Period 3", period: 3, start: "12:26", end: "13:57"),
                SchoolBlockDef(label: "Period 4", period: 4, start: "14:04", end: "15:35"),
            ],
        ],
        holidays: [],
        // No Royal Time the first two weeks (Ethan, 2026-08-19): those
        // Mon/Weds run the Friday (regular, no-RT) bells. RT resumes 9/2.
        dayOverrides: [
            "2026-08-19": "fri",
            "2026-08-24": "fri",
            "2026-08-26": "fri",
            "2026-08-31": "fri",
        ]
    )

    private static let royalDay = [
        SchoolBlockDef(label: "Period 1", period: 1, start: "8:30", end: "9:50"),
        SchoolBlockDef(label: "Royal Time", period: nil, start: "10:01", end: "10:37"),
        SchoolBlockDef(label: "Period 2", period: 2, start: "10:44", end: "12:06"),
        SchoolBlockDef(label: "Lunch", period: nil, start: "12:06", end: "12:41"),
        SchoolBlockDef(label: "Period 3", period: 3, start: "12:48", end: "14:08"),
        SchoolBlockDef(label: "Period 4", period: 4, start: "14:15", end: "15:35"),
    ]

    private static let lateDay = [
        SchoolBlockDef(label: "Period 1", period: 1, start: "9:20", end: "10:38"),
        SchoolBlockDef(label: "Period 2", period: 2, start: "10:49", end: "12:10"),
        SchoolBlockDef(label: "Lunch", period: nil, start: "12:10", end: "12:45"),
        SchoolBlockDef(label: "Period 3", period: 3, start: "12:52", end: "14:10"),
        SchoolBlockDef(label: "Period 4", period: 4, start: "14:17", end: "15:35"),
    ]
}
