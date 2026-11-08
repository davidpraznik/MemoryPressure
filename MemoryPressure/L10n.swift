import Foundation

enum L10n {
    // Angleščina je privzeta, slovenščina se vklopi z nastavitvijo jezika "si"
    static func t(_ en: String, _ si: String) -> String {
        UserDefaults.standard.string(forKey: "language") == "si" ? si : en
    }
}
