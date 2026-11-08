import Foundation
import Darwin

final class SystemStats {
    private var prevTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    // CPU v odstotkih (0 do 100), razlika od zadnjega branja
    func cpuPercent() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let now = (user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        defer { prevTicks = now }
        guard let prev = prevTicks else { return 0 }

        let user = Double(now.user &- prev.user)
        let system = Double(now.system &- prev.system)
        let idle = Double(now.idle &- prev.idle)
        let nice = Double(now.nice &- prev.nice)
        let total = user + system + idle + nice
        return total > 0 ? (user + system + nice) / total * 100 : 0
    }

    // RAM kot v Activity Monitor: app memory + wired + compressed
    func memory() -> (usedGB: Double, totalGB: Double, percent: Double) {
        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS else { return (0, total / 1e9, 0) }

        let page = Double(getpagesize())
        let appPages = Double(vm.internal_page_count) - Double(vm.purgeable_count)
        let used = (appPages + Double(vm.wire_count) + Double(vm.compressor_page_count)) * page
        return (used / 1e9, total / 1e9, used / total * 100)
    }
}
