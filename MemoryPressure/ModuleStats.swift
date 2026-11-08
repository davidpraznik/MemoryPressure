import Foundation
import IOKit

// MARK: - GPU

enum GPUReader {
    // Nedokumentiran ključ v IOAccelerator; če ga macOS kdaj odstrani, vrne nil
    static func utilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOAccelerator"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var best: Double?
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if let raw = IORegistryEntryCreateCFProperty(entry, "PerformanceStatistics" as CFString,
                                                         kCFAllocatorDefault, 0)?.takeRetainedValue(),
               let stats = raw as? [String: Any],
               let value = (stats["Device Utilization %"] as? NSNumber)?.doubleValue {
                best = max(best ?? 0, value)
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return best
    }
}

// MARK: - Disk

enum DiskReader {
    // Decimalni GB, enako kot Finder
    static func read() -> (freeGB: Double, usedGB: Double, percent: Double)? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey,
                                                             .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage,
              total > 0 else { return nil }
        let t = Double(total)
        let f = Double(free)
        return (f / 1_000_000_000, (t - f) / 1_000_000_000, (t - f) / t * 100)
    }
}

// MARK: - Network

final class NetworkReader {
    private var last: [String: (rx: UInt32, tx: UInt32)] = [:]
    private var lastTime: Date?

    func reset() {
        last = [:]
        lastTime = nil
    }

    // Bajti na sekundo; prvi klic po reset() vrne 0
    func sample() -> (down: Double, up: Double) {
        var current: [String: (rx: UInt32, tx: UInt32)] = [:]
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return (0, 0) }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let flags = Int32(ifa.pointee.ifa_flags)
            if let addr = ifa.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK),
               flags & IFF_UP != 0,
               flags & IFF_LOOPBACK == 0,
               let data = ifa.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                let name = String(cString: ifa.pointee.ifa_name)
                if name.hasPrefix("en") {
                    current[name] = (data.pointee.ifi_ibytes, data.pointee.ifi_obytes)
                }
            }
            cursor = ifa.pointee.ifa_next
        }

        let now = Date()
        let previous = last
        let previousTime = lastTime
        last = current
        lastTime = now

        guard let t = previousTime else { return (0, 0) }
        let dt = now.timeIntervalSince(t)
        guard dt > 0.2 else { return (0, 0) }

        var down = 0.0
        var up = 0.0
        for (name, c) in current {
            if let p = previous[name] {
                down += Double(c.rx &- p.rx)   // 32-bitni števec, &- prenese prelom
                up += Double(c.tx &- p.tx)
            }
        }
        return (down / dt, up / dt)
    }
}

// MARK: - Ventilator (SMC)

private struct SMCVers { var major: UInt8 = 0; var minor: UInt8 = 0; var build: UInt8 = 0; var reserved: UInt8 = 0; var release: UInt16 = 0 }
private struct SMCPLimit { var version: UInt16 = 0; var length: UInt16 = 0; var cpu: UInt32 = 0; var gpu: UInt32 = 0; var mem: UInt32 = 0 }
private struct SMCKeyInfo { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0; var pad1: UInt8 = 0; var pad2: UInt8 = 0; var pad3: UInt8 = 0 }
private typealias SMCBytes = (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8)
private struct SMCData {
    var key: UInt32 = 0
    var vers = SMCVers()
    var pLimit = SMCPLimit()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

final class FanReader {
    private var conn: io_connect_t = 0
    private(set) var count = 0

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else {
            conn = 0
            return
        }
        if let fan = readRaw("FNum"), fan.type == "ui8 ", let n = fan.bytes.first {
            count = Int(n)
        }
    }

    deinit {
        if conn != 0 { IOServiceClose(conn) }
    }

    // Najvišji trenutni RPM med ventilatorji
    func rpm() -> Double? {
        guard conn != 0, count > 0 else { return nil }
        var best: Double?
        for i in 0..<count {
            if let item = readRaw("F\(i)Ac"), item.type == "flt ", item.bytes.count == 4 {
                let value = Double(item.bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
                best = max(best ?? 0, value)
            }
        }
        return best
    }

    private func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private func fourCCString(_ v: UInt32) -> String {
        String(bytes: [UInt8((v >> 24) & 255), UInt8((v >> 16) & 255),
                       UInt8((v >> 8) & 255), UInt8(v & 255)], encoding: .ascii) ?? "?"
    }

    private func call(_ input: inout SMCData) -> SMCData? {
        var out = SMCData()
        var outSize = MemoryLayout<SMCData>.stride
        let r = IOConnectCallStructMethod(conn, 2, &input, MemoryLayout<SMCData>.stride, &out, &outSize)
        return (r == KERN_SUCCESS && out.result == 0) ? out : nil
    }

    private func readRaw(_ key: String) -> (type: String, bytes: [UInt8])? {
        var input = SMCData()
        input.key = fourCC(key)
        input.data8 = 9
        guard let info = call(&input) else { return nil }
        input.keyInfo.dataSize = info.keyInfo.dataSize
        input.data8 = 5
        guard let out = call(&input) else { return nil }
        let size = Int(info.keyInfo.dataSize)
        var raw: [UInt8] = []
        withUnsafeBytes(of: out.bytes) { raw = Array($0.prefix(size)) }
        return (fourCCString(info.keyInfo.dataType), raw)
    }
}
