import SwiftUI

/// Today's bell schedule with the live block highlighted — Ethan's classes,
/// rooms, and a countdown on whatever is happening right now.
struct SchoolView: View {
    @EnvironmentObject var school: ScheduleService

    private let gold = Color(red: 0.83, green: 0.66, blue: 0.31)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("SCHOOL")
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
        }
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
                .frame(width: 2, height: 12)

            Text(ScheduleService.clockFmt.string(from: block.start))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(.white.opacity(state == .past ? 0.3 : 0.6))

            Text(title)
                .font(.system(size: 11.5, weight: state == .current ? .semibold : .regular))
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

    private var title: String {
        if let cls = block.cls { return cls.name }
        return block.label
    }
}
