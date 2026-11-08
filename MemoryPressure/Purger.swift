import Foundation

enum Purger {
    // Čiščenje brez gesla (zahteva pravilo v /etc/sudoers.d/memorypressure).
    // Vrne true, če je uspelo.
    static func runSilently(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-n", "/usr/sbin/purge"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            var ok = false
            do {
                try process.run()
                process.waitUntilExit()
                ok = process.terminationStatus == 0
            } catch {
                ok = false
            }
            DispatchQueue.main.async { completion(ok) }
        }
    }

    // Gumb: najprej brez gesla, če ne gre, pokaže sistemsko okno za geslo
    static func run() {
        runSilently { ok in
            if !ok { runWithPassword() }
        }
    }

    private static func runWithPassword() {
        let source = "do shell script \"/usr/sbin/purge\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            print("purge napaka: \(error)")
        }
    }
}
