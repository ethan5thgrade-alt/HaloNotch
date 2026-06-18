import EventKit
import Combine

/// Today's upcoming calendar events via EventKit. Access is requested lazily
/// the first time the clock module appears, so the app runs fine without it.
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    @Published var events: [EKEvent] = []
    @Published var authorized = false
    @Published var didRequest = false

    private let store = EKEventStore()
    private var timer: Timer?
    private init() {}

    func requestIfNeeded() {
        guard !didRequest else { return }
        didRequest = true
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.authorized = granted
                if granted {
                    self?.reload()
                    self?.timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                        self?.reload()
                    }
                }
            }
        }
    }

    func reload() {
        let cal = Calendar.current
        let start = Date()
        guard let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: start)) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let upcoming = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > start }
            .sorted { $0.startDate < $1.startDate }
        events = Array(upcoming.prefix(4))
    }
}
