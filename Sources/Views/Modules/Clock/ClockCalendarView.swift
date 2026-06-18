import SwiftUI
import EventKit

struct ClockCalendarView: View {
    @EnvironmentObject var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(context.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if calendar.authorized {
                if calendar.events.isEmpty {
                    Text("No more events today")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    ForEach(calendar.events.prefix(2), id: \.eventIdentifier) { event in
                        EventRow(event: event)
                    }
                }
            } else if calendar.didRequest {
                Text("Calendar access off")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .onAppear { calendar.requestIfNeeded() }
    }
}

private struct EventRow: View {
    let event: EKEvent

    private var dotColor: Color {
        if let cg = event.calendar?.cgColor { return Color(cgColor: cg) }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
            Text(event.startDate, format: .dateTime.hour().minute())
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.6))
            Text(event.title ?? "Event")
                .font(.system(size: 11))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
