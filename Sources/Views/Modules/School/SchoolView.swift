import SwiftUI

/// Full-tray school panel (entered via the 🎓 button, like the mirror):
/// today's bell schedule on the left, the homework queue on the right —
/// sized to fit the standard tray exactly, no overflow.
struct SchoolPanel: View {
    @EnvironmentObject var school: ScheduleService
    @EnvironmentObject var homework: HomeworkService

    private let gold = Color(red: 0.83, green: 0.66, blue: 0.31)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: today's schedule
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("TODAY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                    Spacer(minLength: 0)
                    if case .during(let i) = school.phase {
                        Text("\(school.minutesLeft(school.blocks[i])) min left")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(gold)
                    }
                }
                .foregroundStyle(.white.opacity(0.55))

                if let reason = school.offReason {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    ForEach(Array(school.blocks.enumerated()), id: \.element.id) { i, block in
                        BlockRow(block: block, state: rowState(i), gold: gold)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Divider().overlay(Color.white.opacity(0.12))

            // Right: homework queue, quick wins first
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "checklist")
                        .font(.system(size: 10, weight: .semibold))
                    Text("HOMEWORK")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                    Text("easiest → biggest")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .foregroundStyle(.white.opacity(0.55))

                if homework.items.isEmpty {
                    Text("Nothing due. Clear runway.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    ForEach(homework.items.prefix(5)) { HomeworkRow(item: $0, gold: gold) }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
    }

    private func rowState(_ i: Int) -> BlockRow.State {
        switch school.phase {
        case .during(let cur): return i == cur ? .current : (i < cur ? .past : .upcoming)
        case .passing(let next): return i < next ? .past : .upcoming
        case .before: return .upcoming
        case .after: return .past
        }
    }
}

private struct BlockRow: View {
    enum State { case past, current, upcoming }
    let block: ResolvedBlock
    let state: State
    let gold: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(state == .current ? gold : .clear)
                .frame(width: 2, height: 11)

            Text(ScheduleService.clockFmt.string(from: block.start))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(.white.opacity(state == .past ? 0.3 : 0.6))

            Text(block.cls?.name ?? block.label)
                .font(.system(size: 11, weight: state == .current ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(state == .past ? 0.35 : (state == .current ? 1 : 0.75)))

            Spacer(minLength: 0)

            if let room = block.cls?.room {
                Text(room)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(state == .past ? 0.25 : 0.45))
            }
        }
    }
}

private struct HomeworkRow: View {
    let item: HomeworkItem
    let gold: Color
    @State private var hovering = false

    var body: some View {
        Button(action: openInLocker) { row }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help("Open in Locker")
    }

    /// Deep-link into the Locker dashboard, straight to this assignment's chat.
    private func openInLocker() {
        if let url = URL(string: "http://localhost:8788/#a\(item.id)") {
            NSWorkspace.shared.open(url)
        }
    }

    private var row: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: item.missing ? "exclamationmark.circle.fill" : "circle")
                .font(.system(size: 8))
                .foregroundStyle(item.missing ? .red.opacity(0.85) : .white.opacity(0.35))

            Text(item.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            if let pts = item.points {
                Text("\(Int(pts))pt")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(dueLabel)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(dueSoon ? gold : .white.opacity(0.5))
        }
        .padding(.horizontal, 3).padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(hovering ? 0.08 : 0)))
        .contentShape(Rectangle())
    }

    private var dueSoon: Bool {
        guard let due = item.due else { return item.missing }
        return due.timeIntervalSinceNow < 48 * 3600
    }

    private var dueLabel: String {
        if item.missing { return "missing" }
        guard let due = item.due else { return "" }
        if Calendar.current.isDateInToday(due) { return "today" }
        if Calendar.current.isDateInTomorrow(due) { return "tmrw" }
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: due)
    }
}
