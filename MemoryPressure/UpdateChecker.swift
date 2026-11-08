import Foundation
import Observation

/// Reads the latest GitHub release and compares it with the installed version.
/// It only tells the user that a newer version exists and links to the release page.
@Observable
final class UpdateChecker {
    enum Problem: Equatable {
        case noRelease, unreadable, offline
    }

    enum State: Equatable {
        case idle, checking, upToDate
        case available(version: String, url: URL)
        case failed(Problem)
    }

    static let shared = UpdateChecker()
    static let repo = "davidpraznik/MemoryPressure"

    var state: State = .idle

    @ObservationIgnored private var timer: Timer?

    var installed: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private var autoEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoUpdate") as? Bool ?? true
    }

    /// Checks at launch and then once a day while the app is running.
    func start() {
        if autoEnabled {
            Task { await check() }
        }
        let t = Timer(timeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.autoEnabled else { return }
                await self.check()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check() async {
        state = .checking
        guard let api = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
            state = .failed(.unreadable)
            return
        }
        do {
            var request = URLRequest(url: api)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 404 {
                state = .failed(.noRelease)
                return
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                state = .failed(.unreadable)
                return
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let page = (json["html_url"] as? String).flatMap(URL.init(string:))
                ?? URL(string: "https://github.com/\(Self.repo)/releases")!
            state = Self.isNewer(latest, than: installed) ? .available(version: latest, url: page) : .upToDate
        } catch {
            state = .failed(.offline)
        }
    }

    /// Compares dotted versions part by part, so 1.0.0 and 1.0 are equal.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0
            let r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    var message: String {
        switch state {
        case .idle:
            return ""
        case .checking:
            return L10n.t("Checking…", "Preverjam…")
        case .upToDate:
            return L10n.t("Up to date.", "Posodobljeno.")
        case .available(let v, _):
            return L10n.t("Version \(v) is available.", "Na voljo je različica \(v).")
        case .failed(.noRelease):
            return L10n.t("No release published yet.", "Izdaja še ni objavljena.")
        case .failed(.unreadable):
            return L10n.t("Could not read the latest release.", "Zadnje izdaje ni mogoče prebrati.")
        case .failed(.offline):
            return L10n.t("Could not reach GitHub.", "GitHuba ni mogoče doseči.")
        }
    }
}
