import SwiftUI

private extension Color {
    static let alertBackground = Color(red: 0.137, green: 0.145, blue: 0.157)   // #232528
    static let alertText = Color(red: 0.949, green: 0.953, blue: 0.961)         // #f2f3f5
    static let alertBody = Color(red: 0.788, green: 0.800, blue: 0.820)         // #c9ccd1
    static let alertCoral = Color(red: 1.0, green: 0.478, blue: 0.400)          // #ff7a66
    static let alertButton = Color(red: 0.812, green: 0.275, blue: 0.188)       // #cf4630
}

struct AlertCard: View {
    var pressure: Double
    var appName: String?
    var appBytes: UInt64?
    var onQuit: () -> Void
    var onClear: () -> Void

    private let locale = Locale(identifier: "sl_SI")

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

    private var bodyText: String {
        if let name = appName, let bytes = appBytes {
            return "\(name) uporablja \(memoryText(bytes)). Ga zapreš ali počistiš predpomnilnik?"
        }
        return "Pomnilnik je skoraj poln. Želiš počistiti predpomnilnik?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.alertCoral)
                    .frame(width: 10, height: 10)
                Text(String(format: "Visok pritisk pomnilnika (%.0f %%)", locale: locale, pressure))
                    .font(mono(14, .bold))
            }
            Text(bodyText)
                .font(mono(13))
                .foregroundStyle(Color.alertBody)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if let name = appName {
                    Button(action: onQuit) {
                        Text("Zapri \(name)")
                            .font(mono(13, .bold))
                            .lineLimit(1)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.alertButton))
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onClear) {
                    Text("Počisti predpomnilnik")
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
