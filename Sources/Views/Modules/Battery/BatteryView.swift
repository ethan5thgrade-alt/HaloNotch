import SwiftUI

struct BatteryView: View {
    @EnvironmentObject var battery: BatteryService

    private var tint: Color {
        if battery.isCharging { return .green }
        if battery.percent <= 20 && !battery.isPluggedIn { return .red }
        return .white
    }

    var body: some View {
        HStack(spacing: 10) {
            BatteryGlyph(percent: battery.percent, charging: battery.isCharging, tint: tint)
                .frame(width: 34, height: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(battery.percent)%")
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        if battery.isCharging {
            return battery.minutesRemaining.map { "\(format($0)) to full" } ?? "Charging"
        }
        if battery.isPluggedIn { return "Plugged in" }
        return battery.minutesRemaining.map { "\(format($0)) left" } ?? "On battery"
    }

    private func format(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

/// A battery shell that fills by percentage, with a charging bolt overlay.
private struct BatteryGlyph: View {
    let percent: Int
    let charging: Bool
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let bodyW = geo.size.width - 3
            let h = geo.size.height
            let shell = RoundedRectangle(cornerRadius: 4, style: .continuous)
            HStack(spacing: 1.5) {
                shell.stroke(.white.opacity(0.5), lineWidth: 1)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(tint)
                            .padding(2)
                            .frame(width: max(2, (bodyW - 4) * CGFloat(percent) / 100))
                    }
                    .frame(width: bodyW, height: h)
                // terminal nub
                Capsule().fill(.white.opacity(0.5))
                    .frame(width: 2, height: h * 0.42)
            }
            .overlay {
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: h * 0.55, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: bodyW, alignment: .center)
                        .offset(x: -1)
                }
            }
        }
    }
}
