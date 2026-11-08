import SwiftUI
import AppKit

private extension Color {
    static let mpBackground = Color(red: 0.137, green: 0.145, blue: 0.157)   // #232528
    static let mpText = Color(red: 0.949, green: 0.953, blue: 0.961)         // #f2f3f5
    static let mpMuted = Color(red: 0.604, green: 0.620, blue: 0.651)        // #9a9ea6
    static let mpGreen = Color(red: 0.435, green: 0.812, blue: 0.498)        // #6fcf7f
    static let mpCoral = Color(red: 1.0, green: 0.478, blue: 0.400)          // #ff7a66
}

struct Sparkline: View {
    var values: [Double]
    var maxValue: Double = 100
    var color: Color

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard values.count > 1 else { return }
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                    let y = geo.size.height * (1 - CGFloat(min(v, maxValue) / maxValue))
                    if i == 0 {
                        p.move(to: CGPoint(x: x, y: y))
                    } else {
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

struct PressureChart: View {
    var values: [Double]
    var limit: Double
    var window: Int = 900   // število vzorcev v oknu (30 min)

    private func points(_ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        let n = values.count
        let step = w / CGFloat(window - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: w - CGFloat(n - 1 - i) * step,
                    y: h * (1 - CGFloat(min(max(v, 0), 100) / 100)))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts = points(w, h)
            ZStack {
                Path { p in
                    guard let first = pts.first, let last = pts.last else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    for pt in pts { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: last.x, y: h))
                    p.closeSubpath()
                }
                .fill(Color.mpGreen.opacity(0.2))

                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Color.mpGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                Path { p in
                    let y = h * (1 - CGFloat(limit / 100))
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w, y: y))
                }
                .stroke(Color.mpCoral, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
    }
}

struct PillToggle: View {
    @Binding var isOn: Bool
    var label: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Color.mpGreen : Color.white.opacity(0.18))
                Circle().fill(Color.white).frame(width: 22, height: 22).padding(3)
            }
            .frame(width: 46, height: 28)
            .animation(.easeInOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PopupView: View {
    var monitor: Monitor
    @AppStorage("remindEnabled") private var remindEnabled = true
    @AppStorage("autoClearEnabled") private var autoClearEnabled = false

    private let pressureLimit = 85.0
    private let locale = Locale(identifier: "sl_SI")

    private var isHot: Bool { monitor.pressure >= pressureLimit }

    private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    private func memoryText(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1e9
        if gb >= 1 {
            return String(format: "%.1f GB", locale: locale, gb)
        }
        return String(format: "%.0f MB", locale: locale, Double(bytes) / 1e6)
    }

    private func quit(_ app: AppUsage) {
        for running in NSWorkspace.shared.runningApplications where running.bundleURL?.path == app.id {
            running.terminate()
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            HStack(spacing: 12) {
                cpuCard
                ramCard
            }
            pressureCard
            clearButton
            processList
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            settingsRows
        }
        .foregroundStyle(Color.mpText)
        .padding(16)
        .frame(width: 380)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.mpBackground))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: isHot ? "exclamationmark" : "checkmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color.mpBackground)
                .frame(width: 28, height: 28)
                .background(Circle().fill(isHot ? Color.mpCoral : Color.mpGreen))
            Text(isHot ? "Visok pritisk" : "Normalno")
                .font(mono(15, .bold))
            Spacer()
            Button {
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.mpMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "cpu").font(.system(size: 13, weight: .bold))
                Text("CPU").font(mono(13, .bold))
            }
            .foregroundStyle(Color.mpGreen)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(format: "%.0f", locale: locale, monitor.cpu)).font(mono(28, .bold))
                Text(" %").font(mono(14)).foregroundStyle(Color.mpMuted)
            }
            Sparkline(values: Array(monitor.cpuHistory.suffix(60)), color: .mpGreen)
                .frame(height: 32)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.055)))
    }

    private var ramCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "memorychip").font(.system(size: 13, weight: .bold))
                    Text("RAM").font(mono(13, .bold))
                }
                .foregroundStyle(Color.mpGreen)
                Spacer()
                Text(String(format: "%.0f %%", locale: locale, monitor.ramPercent))
                    .font(mono(12))
                    .foregroundStyle(Color.mpGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.mpGreen.opacity(0.18)))
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(format: "%.1f", locale: locale, monitor.ramUsedGB)).font(mono(28, .bold))
                Text(" GB").font(mono(14)).foregroundStyle(Color.mpMuted)
            }
            Text(String(format: "od %.0f GB", locale: locale, monitor.ramTotalGB))
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.055)))
    }

    private var pressureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PRITISK POMNILNIKA")
                    .font(mono(13, .bold))
                    .foregroundStyle(Color.mpGreen)
                Spacer()
                Text("30 min")
                    .font(mono(12))
                    .foregroundStyle(Color.mpMuted)
            }
            PressureChart(values: monitor.pressureHistory, limit: pressureLimit)
                .frame(height: 60)
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 14, height: 2)
                    .overlay(
                        Line()
                            .stroke(Color.mpCoral, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                    )
                Text(String(format: "Zgornja meja: %.0f %%", locale: locale, pressureLimit))
                    .font(mono(12))
                    .foregroundStyle(Color.mpMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.055)))
    }

    private var clearButton: some View {
        VStack(spacing: 8) {
            Button {
                Purger.run()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                    Text("Počisti pomnilnik")
                        .font(mono(14, .bold))
                }
                .foregroundStyle(Color(red: 0.106, green: 0.114, blue: 0.122))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.925, green: 0.933, blue: 0.941)))
            }
            .buttonStyle(.plain)
            Text("Izprazni predpomnilnik (purge). Zahteva skrbniške pravice.")
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var processList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("PROCESI")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("POMNILNIK")
                    .frame(width: 96, alignment: .trailing)
                Text("ZAPRI")
                    .frame(width: 44, alignment: .center)
            }
            .font(mono(12, .bold))
            .foregroundStyle(Color.mpMuted)
            .frame(height: 32)

            ForEach(monitor.apps) { app in
                HStack(spacing: 0) {
                    Text(app.name)
                        .font(mono(14))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(memoryText(app.bytes))
                        .font(mono(14))
                        .foregroundStyle(Color.mpMuted)
                        .frame(width: 96, alignment: .trailing)
                    Button {
                        quit(app)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.mpText)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, alignment: .center)
                }
                .frame(height: 44)
            }
        }
        .padding(.horizontal, 4)
    }

    private var settingsRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Opomnik ob visokem pritisku")
                    .font(mono(14))
                Spacer()
                PillToggle(isOn: $remindEnabled, label: "Opomnik ob visokem pritisku")
            }
            .frame(height: 52)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Samodejno čiščenje")
                        .font(mono(14))
                    Text(String(format: "pri %.0f %%, vsaj 10 min razmika", locale: locale, pressureLimit))
                        .font(mono(12))
                        .foregroundStyle(Color.mpMuted)
                }
                Spacer()
                PillToggle(isOn: $autoClearEnabled, label: "Samodejno čiščenje")
            }
            .frame(height: 52)
        }
        .padding(.horizontal, 4)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
