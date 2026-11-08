import SwiftUI
import AppKit

struct RGB {
    let r: Double, g: Double, b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
    var ns: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}

enum AccentOption: String, CaseIterable, Identifiable {
    case multi, blue, purple, pink, red, orange, green, grey

    var id: String { rawValue }

    // Barva za enobarvni način (multi nima enotne barve)
    var rgb: RGB? {
        switch self {
        case .multi:  return nil
        case .blue:   return RGB(r: 0.298, g: 0.537, b: 1.000) // #4c89ff
        case .purple: return RGB(r: 0.678, g: 0.204, b: 0.847) // #ad34d8
        case .pink:   return RGB(r: 0.867, g: 0.184, b: 0.647) // #dd2fa5
        case .red:    return RGB(r: 0.878, g: 0.231, b: 0.251) // #e03b40
        case .orange: return RGB(r: 0.910, g: 0.557, b: 0.204) // #e88e34
        case .green:  return RGB(r: 0.435, g: 0.812, b: 0.498) // #6fcf7f
        case .grey:   return RGB(r: 0.553, g: 0.553, b: 0.576) // #8d8d93
        }
    }

    var accessibilityName: String {
        self == .multi ? "Multicolour" : rawValue.capitalized
    }
}

enum Theme {
    static let key = "accent"

    static let normalRGB = RGB(r: 0.435, g: 0.812, b: 0.498) // zelena #6fcf7f
    static let warnRGB = RGB(r: 1.0, g: 0.478, b: 0.4)       // koralna #ff7a66
    static let linkRGB = RGB(r: 0.431, g: 0.659, b: 1.0)     // povezava #6ea8ff

    static func option(from raw: String) -> AccentOption {
        AccentOption(rawValue: raw) ?? .multi
    }

    // Za SwiftUI (preda se vrednost iz @AppStorage("accent"))
    static func normal(_ raw: String) -> Color {
        (option(from: raw).rgb ?? normalRGB).color
    }

    static func warn(_ raw: String) -> Color {
        (option(from: raw).rgb ?? warnRGB).color
    }

    // Povezava: pri večbarvnem ostane modra, pri enobarvnem sledi izbrani barvi
    static func link(_ raw: String) -> Color {
        (option(from: raw).rgb ?? linkRGB).color
    }

    // Primarni gumb v opomniku. Večbarvno: temen koral #cf4630 z belim napisom.
    // Enobarvno: temnejša različica izbrane barve (svetlost 88 %, nasičenost 106 %).
    // Če je ta še vedno svetla (oranžna, zelena, siva), ostane izbrana barva z temnim napisom.
    static func alertButton(_ raw: String) -> (fill: Color, text: Color) {
        guard let base = option(from: raw).rgb else {
            return (Color(red: 0.812, green: 0.275, blue: 0.188), Color.white) // #cf4630
        }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let darkNS = NSColor(hue: h, saturation: min(1, s * 1.06), brightness: b * 0.88, alpha: 1)
        let dark = darkNS.usingColorSpace(.sRGB) ?? darkNS
        if luminance(dark) <= 0.2 {
            return (Color(nsColor: dark), Color.white)
        }
        return (base.color, Color(red: 0.106, green: 0.114, blue: 0.122)) // #1b1d1f
    }

    private static func luminance(_ c: NSColor) -> Double {
        func lin(_ v: CGFloat) -> Double {
            let x = Double(v)
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
    }

    // Za AppKit (menubar), bere neposredno iz UserDefaults
    static var currentRaw: String {
        UserDefaults.standard.string(forKey: key) ?? "multi"
    }

    static var warnNS: NSColor {
        (option(from: currentRaw).rgb ?? warnRGB).ns
    }
}
