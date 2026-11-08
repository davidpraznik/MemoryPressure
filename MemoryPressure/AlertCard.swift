import SwiftUI

private extension Color {
    static let alertBackground = Color(red: 0.137, green: 0.145, blue: 0.157)   // #232528
    static let alertText = Color(red: 0.949, green: 0.953, blue: 0.961)         // #f2f3f5
    static let alertBody = Color(red: 0.788, green: 0.800, blue: 0.820)         // #c9ccd1
}

struct AlertCard: View {
    var pressure: Double
    var appName: String?
    var appBytes: UInt64?
    var onQuit: () -> Void
    var onClear: () -> Void

    @AppStorage("language") private var language = "en"
    @AppStorage("accent") private var accent = "multi"

    private var locale: Locale {
        Locale(identifier: language == "si" ? "sl_SI" : "en_US")
    }

    private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Enake enote kot v seznamu procesov (1 GB = 2^30 B)
    private func memoryText(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", locale: locale, gb)
        }
        return String(format: "%.0f MB", locale: locale, Double(bytes) / 1_048_576)
    }

    private var titleText: String {
        String(format: L10n.t("High memory pressure (%.0f %%)", "Visok pritisk pomnilnika (%.0f %%)"),
               locale: locale, pressure)
    }

    private var bodyText: String {
        if let name = appName, let bytes = appBytes {
            let mem = memoryText(bytes)
            return L10n.t("\(name) is using \(mem). Quit it or clear the cache?",
                          "\(name) uporablja \(mem). Ga zapreš ali počistiš predpomnilnik?")
        }
        return L10n.t("Memory is almost full. Clear the cache?",
                      "Pomnilnik je skoraj poln. Želiš počistiti predpomnilnik?")
    }

    var body: some View {
        let button = Theme.alertButton(accent)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.warn(accent))
                    .frame(width: 10, height: 10)
                Text(titleText)
                    .font(mono(14, .bold))
            }
            Text(bodyText)
                .font(mono(13))
                .foregroundStyle(Color.alertBody)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if let name = appName {
                    Button(action: onQuit) {
                        Text(L10n.t("Quit \(name)", "Zapri \(name)"))
                            .font(mono(13, .bold))
                            .lineLimit(1)
                            .foregroundStyle(button.text)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(button.fill))
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onClear) {
                    Text(L10n.t("Clear cache", "Počisti predpomnilnik"))
                        .font(mono(13, .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Color.alertText)
        .padding(16)
        .frame(width: 420, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.alertBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }
}
