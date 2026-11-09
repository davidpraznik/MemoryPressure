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

private enum Module: Hashable {
    case gpu, disk, net, fan
}

// MARK: - Popup

struct PopupView: View {
    let monitor: Monitor
    var arrow: ArrowModel = ArrowModel()

    @AppStorage("language") private var language = "en"
    @AppStorage("accent") private var accent = "multi"
    @AppStorage("pressureLimit") private var pressureLimit = 85.0
    @AppStorage("moduleGPU") private var moduleGPU = true
    @AppStorage("moduleDisk") private var moduleDisk = true
    @AppStorage("moduleNet") private var moduleNet = true
    @AppStorage("moduleFan") private var moduleFan = true

    @State private var showSettings = false
    @State private var contentHeight: CGFloat = 0

    private let caretWidth: CGFloat = 18
    private let caretHeight: CGFloat = 8
    private let cardPad = EdgeInsets(top: 9, leading: 11, bottom: 9, trailing: 11)

    private var tint: Color { Theme.normal(accent) }
    private var warnTint: Color { Theme.warn(accent) }
    private var linkTint: Color { Theme.link(accent) }

    // Največja višina okna: višina uporabnega dela zaslona (brez menubara in docka) z malo roba
    private var maxPanelHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 24
    }

    private var content: some View {
        Group {
            if showSettings {
                SettingsView(onBack: { showSettings = false })
            } else {
                mainContent
            }
        }
        .padding(12)
        .frame(width: 380)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            contentHeight = height
        }
    }

    var body: some View {
        let limit = maxPanelHeight - caretHeight
        Group {
            if contentHeight > limit {
                // Vsebina je višja od zaslona: okno se omeji na zaslon, vsebina se pomika
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
                .frame(width: 380, height: limit)
            } else {
                content
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
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
        .onChange(of: contentHeight) { _, _ in
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
        VStack(spacing: 6) {
            header
            HStack(spacing: 6) {
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
            copyright
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
    }

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 12).fill(Color.mpCard)
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

    // Glava je visoka 20. Zobnik je enako velik kot ikona za izhod v nogi (15 pt, krepko),
    // klikljivo področje je večje in ne povečuje vrstice.
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.mpMuted)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -8)
            .padding(.vertical, -8)
            .accessibilityLabel(L10n.t("Settings", "Nastavitve"))
        }
        .frame(height: 20)
    }

    // MARK: Cards

    private func cardTitle(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text.uppercased())
                .font(mono(12, .bold))
        }
        .foregroundStyle(tint)
        .frame(height: 18)
    }

    private func bigValue(_ value: String, unit: String, size: CGFloat = 26) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(value)
                .font(mono(size, .bold))
            Text(" \(unit)")
                .font(mono(size >= 26 ? 13 : 12, .medium))
                .foregroundStyle(Color.mpMuted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            cardTitle("cpu", "CPU")
            HStack(alignment: .bottom, spacing: 4) {
                bigValue("\(Int(monitor.cpu.rounded()))", unit: "%")
                Spacer(minLength: 0)
                Sparkline(values: monitor.cpuHistory, color: tint)
                    .frame(width: 70, height: 24)
            }
        }
        .padding(cardPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground())
    }

    private var ramCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                cardTitle("memorychip", "RAM")
                Spacer()
                Text("\(Int(monitor.ramPercent.rounded())) %")
                    .font(mono(11))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(tint.opacity(0.18)))
            }
            bigValue(decimal(monitor.ramUsedGB), unit: "GB")
        }
        .padding(cardPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground())
        .help(L10n.t("of \(decimal(monitor.ramTotalGB, digits: 0)) GB",
                     "od \(decimal(monitor.ramTotalGB, digits: 0)) GB"))
    }

    private var pressureCard: some View {
        let pillColor = isHigh ? warnTint : tint
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(L10n.t("MEMORY PRESSURE", "PRITISK POMNILNIKA"))
                    .font(mono(12, .bold))
                    .foregroundStyle(tint)
                Spacer()
                Text("\(Int(monitor.pressure.rounded())) %")
                    .font(mono(11))
                    .foregroundStyle(pillColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(pillColor.opacity(0.18)))
            }
            PressureChart(values: monitor.pressureHistory,
                          limit: pressureLimit,
                          lineColor: tint,
                          limitColor: warnTint)
                .frame(height: 40)
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
        .padding(cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    // MARK: Clear

    private var clearButton: some View {
        VStack(spacing: 6) {
            Button {
                Purger.run()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .semibold))
                    Text(L10n.t("Clear memory", "Počisti pomnilnik"))
                        .font(mono(14, .bold))
                }
                .foregroundStyle(Color.mpDark)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
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
            HStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 2) {
            content()
        }
        .padding(cardPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground())
    }

    private var gpuCard: some View {
        moduleBox {
            cardTitle("display", "GPU")
            HStack(alignment: .bottom, spacing: 4) {
                bigValue(monitor.gpu.map { "\(Int($0.rounded()))" } ?? "n/a",
                         unit: monitor.gpu == nil ? "" : "%", size: 22)
                Spacer(minLength: 0)
                Sparkline(values: monitor.gpuHistory, color: tint)
                    .frame(width: 64, height: 22)
            }
        }
    }

    private var diskCard: some View {
        moduleBox {
            cardTitle("internaldrive", L10n.t("Disk", "Disk"))
            bigValue(decimal(monitor.diskFreeGB), unit: L10n.t("GB free", "GB prosto"), size: 22)
        }
        .help(L10n.t("\(decimal(monitor.diskUsedGB)) GB used · \(Int(monitor.diskPercent.rounded())) %",
                     "\(decimal(monitor.diskUsedGB)) GB zasedeno · \(Int(monitor.diskPercent.rounded())) %"))
    }

    private var netCard: some View {
        let down = formatRate(monitor.netDown)
        let up = formatRate(monitor.netUp)
        // Graf se prilagodi največji hitrosti, najmanj 100 KB/s, da majhen promet ne skače čez vso višino
        let top = max(monitor.netHistory.suffix(60).max() ?? 0, 100_000)
        return moduleBox {
            cardTitle("network", L10n.t("Network", "Omrežje"))
            HStack(alignment: .bottom, spacing: 4) {
                bigValue(down.value, unit: down.unit, size: 22)
                Spacer(minLength: 0)
                Sparkline(values: monitor.netHistory, color: tint, scale: top)
                    .frame(width: 64, height: 22)
            }
        }
        .help("↑ \(up.value) \(up.unit)")
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
                     unit: monitor.fanRPM == nil ? "" : "RPM", size: 22)
        }
        .help(fanCountLabel)
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
            .font(mono(11, .bold))
            .foregroundStyle(Color.mpMuted)
            .padding(.horizontal, 4)
            .frame(height: 20)

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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.mpText)
                            .frame(width: 56, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Quit \(app.name)", "Zapri \(app.name)"))
                }
                .padding(.horizontal, 4)
                .frame(height: 24)
            }
        }
        .padding(.top, 2)
    }

    private func quit(_ app: AppUsage) {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleURL?.path == app.id }
            .forEach { $0.terminate() }
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
        .padding(.top, 2)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
