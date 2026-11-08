import SwiftUI
import AppKit
import ServiceManagement

private extension Color {
    static let sText = Color(red: 0.949, green: 0.953, blue: 0.961)   // #f2f3f5
    static let sMuted = Color(red: 0.604, green: 0.620, blue: 0.651)  // #9a9ea6
    static let sDark = Color(red: 0.106, green: 0.114, blue: 0.122)   // #1b1d1f
    static let sCard = Color.white.opacity(0.055)
}

private struct SettingsPill: View {
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

struct SettingsView: View {
    var onBack: () -> Void

    @AppStorage("language") private var language = "en"
    @AppStorage("accent") private var accent = "multi"
    @AppStorage("pressureLimit") private var pressureLimit = 85.0
    @AppStorage("cpuLimit") private var cpuLimit = 90.0
    @AppStorage("moduleGPU") private var moduleGPU = true
    @AppStorage("moduleDisk") private var moduleDisk = true
    @AppStorage("moduleNet") private var moduleNet = true
    @AppStorage("moduleFan") private var moduleFan = true

    @State private var launchAtLogin = false

    private var tint: Color { Theme.normal(accent) }

    private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            languageCard
            accentCard
            modulesCard
            limitCard(
                title: L10n.t("Memory pressure limit", "Meja pritiska pomnilnika"),
                note: L10n.t("Reminder and auto clear start at this level.",
                             "Opomnik in samodejno čiščenje se sprožita pri tej meji."),
                value: $pressureLimit,
                range: 60...95
            )
            limitCard(
                title: L10n.t("CPU limit", "Meja CPU"),
                note: L10n.t("The CPU number in the menu bar changes colour at this level.",
                             "Številka CPU v menubaru spremeni barvo pri tej meji."),
                value: $cpuLimit,
                range: 70...100
            )
            launchRow
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            footer
        }
        .foregroundStyle(Color.sText)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: Header

    // Glava je visoka toliko kot vsebina (20). Okvir puščice je enak širini glifa (9),
    // zato je razmik do naslova optično enak kot pri statusni ikoni na prvi strani (8).
    // Klikljivo področje je večje, ne vpliva na razporeditev.
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.sText)
                    .frame(width: 9, height: 44)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -8)
            .padding(.vertical, -12)
            .accessibilityLabel(L10n.t("Back", "Nazaj"))
            Text(L10n.t("Settings", "Nastavitve"))
                .font(mono(15, .bold))
            Spacer()
        }
        .frame(height: 20)
    }

    // MARK: Language

    private var languageCard: some View {
        HStack {
            Text(L10n.t("Language", "Jezik"))
                .font(mono(14))
            Spacer()
            HStack(spacing: 0) {
                languageButton("EN", code: "en")
                languageButton("SI", code: "si")
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
        }
        .padding(EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 7))
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.sCard))
    }

    private func languageButton(_ label: String, code: String) -> some View {
        let selected = language == code
        return Button {
            language = code
        } label: {
            Text(label)
                .font(mono(13, .bold))
                .foregroundStyle(selected ? Color.sDark : Color.sText)
                .frame(width: 56, height: 32)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color(red: 0.925, green: 0.933, blue: 0.941) : Color.clear))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: Accent

    private var accentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("Accent colour", "Barva poudarka"))
                .font(mono(14))
            HStack {
                ForEach(Array(AccentOption.allCases.enumerated()), id: \.element.id) { index, option in
                    if index > 0 { Spacer(minLength: 0) }
                    swatch(option)
                }
            }
            Text(L10n.t("Multicolour uses green for normal and coral for warnings. A single colour is used for everything.",
                        "Večbarvno uporablja zeleno za normalno stanje in koralno za opozorila. Ena barva se uporabi za vse."))
                .font(mono(12))
                .foregroundStyle(Color.sMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.sCard))
    }

    private func swatch(_ option: AccentOption) -> some View {
        let selected = accent == option.rawValue
        return Button {
            accent = option.rawValue
        } label: {
            ZStack {
                Circle()
                    .stroke(selected ? Color.sText : Color.clear, lineWidth: 2)
                    .frame(width: 36, height: 36)
                if let rgb = option.rgb {
                    Circle()
                        .fill(rgb.color)
                        .frame(width: 26, height: 26)
                } else {
                    multicolourIcon
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.accessibilityName)
    }

    private var multicolourIcon: some View {
        let dots: [Color] = [
            Color(red: 0.816, green: 0.227, blue: 0.227), // rdeča
            Color(red: 0.933, green: 0.545, blue: 0.231), // oranžna
            Color(red: 0.361, green: 0.710, blue: 0.478), // zelena
            Color(red: 0.290, green: 0.659, blue: 0.910), // modra
            Color(red: 0.690, green: 0.463, blue: 0.941), // vijolična
            Color(red: 0.937, green: 0.435, blue: 0.753)  // roza
        ]
        return ZStack {
            Circle().fill(Color.white).frame(width: 26, height: 26)
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * 60.0 - 90.0
                Circle()
                    .fill(dots[i])
                    .frame(width: 6.6, height: 6.6)
                    .offset(x: 8.2 * cos(angle * .pi / 180), y: 8.2 * sin(angle * .pi / 180))
            }
            Circle().fill(Color(red: 0.067, green: 0.071, blue: 0.078)).frame(width: 6.6, height: 6.6)
        }
    }

    // MARK: Modules

    private func moduleToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(mono(14))
            Spacer()
            SettingsPill(isOn: isOn, tint: tint)
        }
        .frame(height: 44)
    }

    private var modulesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t("Modules", "Moduli"))
                .font(mono(14))
                .padding(.bottom, 4)
            moduleToggleRow("GPU", isOn: $moduleGPU)
            moduleToggleRow(L10n.t("Disk", "Disk"), isOn: $moduleDisk)
            moduleToggleRow(L10n.t("Network", "Omrežje"), isOn: $moduleNet)
            moduleToggleRow(L10n.t("Fans", "Ventilatorji"), isOn: $moduleFan)
            Text(L10n.t("Shown in the popup. Fans appear only on Macs with a fan.",
                        "Prikazani so v oknu. Ventilatorji se pojavijo samo na Macih z ventilatorjem."))
                .font(mono(12))
                .foregroundStyle(Color.sMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.sCard))
    }

    // MARK: Limits

    private func limitCard(title: String, note: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(mono(14))
                Spacer()
                Text("\(Int(value.wrappedValue)) %")
                    .font(mono(14, .bold))
                    .foregroundStyle(tint)
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
            Text(note)
                .font(mono(12))
                .foregroundStyle(Color.sMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.sCard))
    }

    // MARK: Launch at login

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { setLaunchAtLogin($0) }
        )
    }

    private var launchRow: some View {
        HStack {
            Text(L10n.t("Launch at login", "Zaženi ob prijavi"))
                .font(mono(14))
            Spacer()
            SettingsPill(isOn: launchBinding, tint: tint)
        }
        .frame(height: 52)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Stanje se spodaj prebere iz sistema, zato se preklopnik vrne na pravo vrednost
        }
        let status = SMAppService.mainApp.status
        if on && status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLogin = status == .enabled
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Memory Pressure 1.0")
                    .font(mono(13, .bold))
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.sMuted)
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
                .foregroundStyle(Color.sMuted)
            Link("github.com/davidpraznik/MemoryPressure",
                 destination: URL(string: "https://github.com/davidpraznik/MemoryPressure")!)
                .font(mono(12))
                .foregroundStyle(Theme.link(accent))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}
