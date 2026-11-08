import Foundation
import Darwin

struct AppUsage: Identifiable {
    let id: String        // pot do .app
    let name: String
    let bytes: UInt64
}

enum ProcessReader {
    static func topApps(limit: Int) -> [AppUsage] {
        let needed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard needed > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(needed) / MemoryLayout<pid_t>.size + 32)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }
        let count = Int(filled) / MemoryLayout<pid_t>.size

        let ownPath = Bundle.main.bundlePath
        var totals: [String: UInt64] = [:]
        var pathBuffer = [CChar](repeating: 0, count: 4096)

        for pid in pids.prefix(count) where pid > 0 {
            let length = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            guard length > 0 else { continue }
            let path = String(cString: pathBuffer)

            let parts = path.components(separatedBy: "/")
            guard let index = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { continue }
            let appPath = parts[0...index].joined(separator: "/")
            if appPath == ownPath { continue }

            var info = rusage_info_current()
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            }
            guard result == 0 else { continue }
            totals[appPath, default: 0] += info.ri_phys_footprint
        }

        return totals
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { path, bytes in
                let file = path.components(separatedBy: "/").last ?? path
                let name = String(file.dropLast(4))
                return AppUsage(id: path, name: name, bytes: bytes)
            }
    }
}
