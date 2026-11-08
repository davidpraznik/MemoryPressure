import Foundation

enum Purger {
    // Passwordless purge. Needs a sudoers rule in /etc/sudoers.d/memorypressure.
    // Calls completion with true on success.
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

    // Button action: try without a password first, otherwise show the system password prompt.
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
            print("purge error: \(error)")
        }
    }
}
