import SwiftUI

struct TimerView: View {
    @EnvironmentObject var pomo: PomodoroController

    var body: some View {
        HStack(spacing: 12) {
            ring
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(pomo.presets, id: \.self) { minutes in
                        presetChip(minutes)
                    }
                }
                HStack(spacing: 14) {
                    iconButton(pomo.isRunning ? "pause.fill" : "play.fill") { pomo.startPause() }
                    iconButton("arrow.counterclockwise") { pomo.reset() }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.16), lineWidth: 4)
            Circle()
                .trim(from: 0, to: pomo.progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(pomo.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 46, height: 46)
        .animation(.easeInOut(duration: 0.3), value: pomo.progress)
    }

    private func presetChip(_ minutes: Int) -> some View {
        let selected = Int(pomo.duration) == minutes * 60
        return Button { pomo.setDuration(minutes: minutes) } label: {
            Text("\(minutes)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    Capsule().fill(selected ? .white.opacity(0.85) : .white.opacity(0.12))
                )
                .foregroundStyle(selected ? .black : .white)
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
