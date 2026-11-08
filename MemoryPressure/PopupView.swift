import SwiftUI
import AppKit

private extension Color {
    static let mpBackground = Color(red: 0.137, green: 0.145, blue: 0.157) // #232528
    static let mpText = Color(red: 0.949, green: 0.953, blue: 0.961)       // #f2f3f5
    static let mpMuted = Color(red: 0.604, green: 0.620, blue: 0.651)      // #9a9ea6
    static let mpDark = Color(red: 0.106, green: 0.114, blue: 0.122)       // #1b1d1f
    static let mpCard = Color.white.opacity(0.055)
}

extension Notification.Name {
    static let popupContentChanged = Notification.Name("popupContentChanged")
}

// Vodoravni položaj trikotnika (sredina) merjen od levega roba okna
@Observable
final class ArrowModel {
    var centerX: CGFloat = 190
}

// MARK: - Helpers

private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}

private func decimal(_ value: Double, digits: Int = 1) -> String {
    let s = String(format: "%.\(digits)f", value)
    return UserDefaults.standard.string(forKey: "language") == "si"
        ? s.replacingOccurrences(of: ".", with: ",")
        : s
}

private func formatBytes(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / 1_073_741_824
    if gb >= 1 { return "\(decimal(gb)) GB" }
    let mb = Double(bytes) / 1_048_576
    return "\(Int(mb)) MB"
}

// Hitrost omrežja v KB/s ali MB/s (decimalno, kot je običajno pri omrežju)
private func formatRate(_ bytesPerSecond: Double) -> (value: String, unit: String) {
    let kb = bytesPerSecond / 1000
    if kb >= 1000 { return (decimal(kb / 1000), "MB/s") }
    return ("\(Int(kb.rounded()))", "KB/s")
}

private struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// Trikotnik nad oknom: polnilo (zaprta oblika) in rob (samo poševni stranici)
private struct CaretShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX - 2.3, y: 1.4))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 2.3, y: 1.4),
                       control: CGPoint(x: rect.midX, y: -1.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct CaretEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX - 2.3, y: 1.4))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 2.3, y: 1.4),
                       control: CGPoint(x: rect.midX, y: -1.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

// MARK: - Charts

// scale = vrednost, ki ustreza polni višini grafa (100 za odstotke)
private struct Sparkline: View {
    let values: [Double]
    let color: Color
    var scale: Double = 100

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let data = Array(values.suffix(60))
            if data.count > 1 {
                let step = w / CGFloat(data.count - 1)
                Path { p in
                    for (i, v) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - CGFloat(min(max(v / scale, 0), 1)) * (h - 4) - 2
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct PressureChart: View {
    let values: [Double]
    let limit: Double
    let lineColor: Color
    let limitColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let window = 900
            let data = Array(values.suffix(window))
            let step = w / CGFloat(window - 1)
            let limitY = h - CGFloat(limit / 100) * h

            ZStack {
                if data.count > 1 {
                    let points: [CGPoint] = data.enumerated().map { i, v in
                        let x = w - CGFloat(data.count - 1 - i) * step
                        let y = h - CGFloat(min(max(v, 0), 100) / 100) * h
                        return CGPoint(x: x, y: y)
                    }
                    Path { p in
                        p.move(to: CGPoint(x: points[0].x, y: h))
                        for pt in points { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: points[points.count - 1].x, y: h))
                        p.closeSubpath()
                    }
                    .fill(lineColor.opacity(0.2))
                    Path { p in
                        p.move(to: points[0])
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                HLine()
                    .stroke(limitColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .frame(width: w, height: 2)
                    .position(x: w / 2, y: limitY)
            }
        }
    }
}

private struct PillToggle: View {
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? tint : Color.white.opacity(0.18))
                    .frame(width: 46, height: 28)
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .padding(3)
            }
            .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
    }
}

private enum Module: Hashable {
    case gpu, disk, net, fan
}

// MARK: - Popup

struct PopupView: View {
    let monitor: Monitor
    var arrow: ArrowModel = ArrowModel()

    @AppStorage("language") private var language = "en"
    @AppStorage("accent") private var accent = "multi"
    @AppStorage("remindEnabled") private var remindEnabled = true
    @AppStorage("autoClearEnabled") private var autoClearEnabled = false
    @AppStorage("pressureLimit") private var pressureLimit = 85.0
    @AppStorage("moduleGPU") private var moduleGPU = true
    @AppStorage("moduleDisk") private var moduleDisk = true
    @AppStorage("moduleNet") private var moduleNet = true
    @AppStorage("moduleFan") private var moduleFan = true

    @State private var showSettings = false

    private let caretWidth: CGFloat = 18
    private let caretHeight: CGFloat = 8

    private var tint: Color { Theme.normal(accent) }
    private var warnTint: Color { Theme.warn(accent) }
    private var linkTint: Color { Theme.link(accent) }

    var body: some View {
        Group {
            if showSettings {
                SettingsView(onBack: { showSettings = false })
            } else {
                mainContent
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.mpBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .foregroundStyle(Color.mpText)
        .padding(.top, caretHeight)
        .overlay(alignment: .topLeading) {
            caret
                .offset(x: arrow.centerX - caretWidth / 2)
        }
        .onChange(of: showSettings) { _, _ in
            NotificationCenter.default.post(name: .popupContentChanged, object: nil)
        }
        .onChange(of: language) { _, _ in
            NotificationCenter.default.post(name: .popupContentChanged, object: nil)
        }
    }

    // Trikotnik, ki kaže proti ikoni v menubaru. Rob okna pod njim je prekrit,
    // da trikotnik izgleda kot del okna.
    private var caret: some View {
        ZStack {
            CaretShape().fill(Color.mpBackground)
            CaretEdge().stroke(Color.white.opacity(0.1), lineWidth: 1)
            Rectangle()
                .fill(Color.mpBackground)
                .frame(width: caretWidth - 4, height: 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: 1)
        }
        .frame(width: caretWidth, height: caretHeight)
    }

    private var isHigh: Bool { monitor.pressure >= pressureLimit }

    private var mainContent: some View {
        VStack(spacing: 12) {
            header
            HStack(spacing: 12) {
                cpuCard
                ramCard
            }
            .fixedSize(horizontal: false, vertical: true)
            pressureCard
            clearButton
            moduleRow([.gpu, .disk])
            moduleRow([.net, .fan])
            processList
            divider
            toggleRows
            divider
            copyright
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
    }

    // MARK: Header

    // Krog je optično poravnan na višino velike črke: osnovna črta besedila,
    // krog pa za malenkost (preseganje) zaide pod črto in nad vrh črke
    private var statusIcon: some View {
        let diameter: CGFloat = 13
        let overshoot: CGFloat = 1.2
        return ZStack {
            Circle()
                .fill(isHigh ? warnTint : tint)
                .frame(width: diameter, height: diameter)
            Image(systemName: isHigh ? "exclamationmark" : "checkmark")
                .font(.system(size: 7.5, weight: .heavy))
                .foregroundStyle(Color.mpDark)
        }
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - overshoot }
    }

    // Glava je visoka toliko kot vsebina (20), da je razmik do kartic enak razmiku med karticami.
    // Zobnik ima večje klikljivo področje, ki ne povečuje vrstice.
    private var header: some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                statusIcon
                Text(isHigh ? L10n.t("High pressure", "Visok pritisk") : L10n.t("Normal", "Normalno"))
                    .font(mono(15, .bold))
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.mpMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -8)
            .padding(.vertical, -12)
            .accessibilityLabel(L10n.t("Settings", "Nastavitve"))
        }
        .frame(height: 20)
    }

    // MARK: Cards

    private func cardTitle(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text.uppercased())
                .font(mono(13, .bold))
        }
        .foregroundStyle(tint)
        .frame(height: 22)
    }

    private func bigValue(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(value)
                .font(mono(28, .bold))
            Text(" \(unit)")
                .font(mono(14, .medium))
                .foregroundStyle(Color.mpMuted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            cardTitle("cpu", "CPU")
            bigValue("\(Int(monitor.cpu.rounded()))", unit: "%")
            Sparkline(values: monitor.cpuHistory, color: tint)
                .frame(height: 32)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mpCard))
    }

    private var ramCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                cardTitle("memorychip", "RAM")
                Spacer()
                Text("\(Int(monitor.ramPercent.rounded())) %")
                    .font(mono(12))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(tint.opacity(0.18)))
            }
            bigValue(decimal(monitor.ramUsedGB), unit: "GB")
            Spacer(minLength: 0)
            Text(L10n.t("of \(decimal(monitor.ramTotalGB, digits: 0)) GB",
                        "od \(decimal(monitor.ramTotalGB, digits: 0)) GB"))
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mpCard))
    }

    private var pressureCard: some View {
        let pillColor = isHigh ? warnTint : tint
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.t("MEMORY PRESSURE", "PRITISK POMNILNIKA"))
                    .font(mono(13, .bold))
                    .foregroundStyle(tint)
                Spacer()
                Text("\(Int(monitor.pressure.rounded())) %")
                    .font(mono(12))
                    .foregroundStyle(pillColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(pillColor.opacity(0.18)))
            }
            PressureChart(values: monitor.pressureHistory,
                          limit: pressureLimit,
                          lineColor: tint,
                          limitColor: warnTint)
                .frame(height: 60)
            HStack(spacing: 6) {
                HLine()
                    .stroke(warnTint, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                    .frame(width: 14, height: 2)
                Text(L10n.t("Upper limit: \(Int(pressureLimit)) %", "Zgornja meja: \(Int(pressureLimit)) %"))
                    .font(mono(12))
                    .foregroundStyle(Color.mpMuted)
                Spacer()
                Text("30 min")
                    .font(mono(12))
                    .foregroundStyle(Color.mpMuted)
            }
            Text(L10n.t("How hard macOS is working to free memory. Not the same as RAM used.",
                        "Kako močno macOS sprošča pomnilnik. To ni isto kot zasedeni RAM."))
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mpCard))
    }

    // MARK: Clear

    private var clearButton: some View {
        VStack(spacing: 8) {
            Button {
                Purger.run()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.t("Clear memory", "Počisti pomnilnik"))
                        .font(mono(14, .bold))
                }
                .foregroundStyle(Color.mpDark)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.925, green: 0.933, blue: 0.941)))
            }
            .buttonStyle(.plain)
            Text(L10n.t("Frees inactive memory (purge). Requires admin rights.",
                        "Izprazni predpomnilnik (purge). Zahteva skrbniške pravice."))
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    // MARK: Modules

    private func isOn(_ module: Module) -> Bool {
        switch module {
        case .gpu: return moduleGPU
        case .disk: return moduleDisk
        case .net: return moduleNet
        case .fan: return moduleFan && monitor.hasFan
        }
    }

    // Vrstica ima dva fiksna mesta; kartica brez para ostane na svojem mestu v polovični širini
    @ViewBuilder
    private func moduleRow(_ items: [Module]) -> some View {
        let active = items.filter { isOn($0) }
        if !active.isEmpty {
            HStack(spacing: 12) {
                ForEach(active, id: \.self) { module in
                    moduleCard(module)
                }
                if active.count == 1 {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func moduleCard(_ module: Module) -> some View {
        switch module {
        case .gpu: gpuCard
        case .disk: diskCard
        case .net: netCard
        case .fan: fanCard
        }
    }

    private func moduleBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mpCard))
    }

    private var gpuCard: some View {
        moduleBox {
            cardTitle("display", "GPU")
            bigValue(monitor.gpu.map { "\(Int($0.rounded()))" } ?? "n/a",
                     unit: monitor.gpu == nil ? "" : "%")
            Sparkline(values: monitor.gpuHistory, color: tint)
                .frame(height: 32)
        }
    }

    private var diskBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(max(monitor.diskPercent, 0), 100) / 100))
            }
        }
        .frame(height: 6)
    }

    private var diskCard: some View {
        moduleBox {
            cardTitle("internaldrive", L10n.t("Disk", "Disk"))
            bigValue(decimal(monitor.diskFreeGB), unit: L10n.t("GB free", "GB prosto"))
            diskBar
                .padding(.top, 8)
            Spacer(minLength: 0)
            Text(L10n.t("\(decimal(monitor.diskUsedGB)) GB used · \(Int(monitor.diskPercent.rounded())) %",
                        "\(decimal(monitor.diskUsedGB)) GB zasedeno · \(Int(monitor.diskPercent.rounded())) %"))
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var netCard: some View {
        let down = formatRate(monitor.netDown)
        let up = formatRate(monitor.netUp)
        // Graf se prilagodi največji hitrosti, najmanj 100 KB/s, da majhen promet ne skače čez vso višino
        let top = max(monitor.netHistory.suffix(60).max() ?? 0, 100_000)
        return moduleBox {
            cardTitle("network", L10n.t("Network", "Omrežje"))
            bigValue(down.value, unit: down.unit)
            Sparkline(values: monitor.netHistory, color: tint, scale: top)
                .frame(height: 32)
            Text("↑ \(up.value) \(up.unit)")
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
        }
    }

    private var fanCountLabel: String {
        let n = monitor.fanCount
        let en = n == 1 ? "1 fan" : "\(n) fans"
        let si = n == 1 ? "1 ventilator" : (n == 2 ? "2 ventilatorja" : "\(n) ventilatorji")
        return L10n.t(en, si)
    }

    private var fanCard: some View {
        moduleBox {
            cardTitle("fan", L10n.t("Fan", "Ventilator"))
            bigValue(monitor.fanRPM.map { "\(Int($0.rounded()))" } ?? "n/a",
                     unit: monitor.fanRPM == nil ? "" : "RPM")
            Spacer(minLength: 0)
            Text(fanCountLabel)
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
        }
    }

    // MARK: Processes

    private var processList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(L10n.t("PROCESSES", "PROCESI"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.t("MEMORY", "POMNILNIK"))
                    .frame(width: 96, alignment: .trailing)
                Text(L10n.t("QUIT", "ZAPRI"))
                    .frame(width: 56, alignment: .center)
            }
            .font(mono(12, .bold))
            .foregroundStyle(Color.mpMuted)
            .padding(.horizontal, 4)
            .frame(height: 32)

            ForEach(monitor.apps) { app in
                HStack(spacing: 0) {
                    Text(app.name)
                        .font(mono(14))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatBytes(app.bytes))
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
                    .frame(width: 56)
                    .accessibilityLabel(L10n.t("Quit \(app.name)", "Zapri \(app.name)"))
                }
                .padding(.horizontal, 4)
                .frame(height: 44)
            }
        }
        .padding(.top, 4)
    }

    private func quit(_ app: AppUsage) {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleURL?.path == app.id }
            .forEach { $0.terminate() }
    }

    // MARK: Toggles

    private var toggleRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.t("Remind me at high pressure", "Opomnik ob visokem pritisku"))
                    .font(mono(14))
                Spacer()
                PillToggle(isOn: $remindEnabled, tint: tint)
            }
            .frame(height: 52)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Auto clear", "Samodejno čiščenje"))
                        .font(mono(14))
                    Text(L10n.t("at \(Int(pressureLimit)) %, at least 10 min apart",
                                "pri \(Int(pressureLimit)) %, vsaj 10 min razmika"))
                        .font(mono(12))
                        .foregroundStyle(Color.mpMuted)
                }
                Spacer()
                PillToggle(isOn: $autoClearEnabled, tint: tint)
            }
            .frame(height: 52)
        }
    }

    // MARK: Footer

    private var copyright: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Memory Pressure \(appVersion)")
                    .font(mono(13, .bold))
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.mpMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -8)
                .accessibilityLabel(L10n.t("Quit Memory Pressure", "Zapri Memory Pressure"))
            }
            .frame(height: 20)
            Text("© 2026 David Praznik")
                .font(mono(12))
                .foregroundStyle(Color.mpMuted)
            Link("github.com/davidpraznik/MemoryPressure",
                 destination: URL(string: "https://github.com/davidpraznik/MemoryPressure")!)
                .font(mono(12))
                .foregroundStyle(linkTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
