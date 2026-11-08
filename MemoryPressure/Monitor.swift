import SwiftUI
import Observation

@Observable
final class Monitor {
    var cpu: Double = 0
    var ramUsedGB: Double = 0
    var ramTotalGB: Double = 0
    var ramPercent: Double = 0
    var pressure: Double = 0          // 0 do 100, višje je slabše
    var cpuHistory: [Double] = []
    var ramHistory: [Double] = []
    var pressureHistory: [Double] = []
    var apps: [AppUsage] = []

    @ObservationIgnored private let stats = SystemStats()
    @ObservationIgnored private let maxSamples = 900   // 30 min pri vzorcu na 2 s

    func refresh() {
        cpu = stats.cpuPercent()
        let mem = stats.memory()
        ramUsedGB = mem.usedGB
        ramTotalGB = mem.totalGB
        ramPercent = mem.percent
        pressure = readPressure()
        apps = ProcessReader.topApps(limit: 4)

        cpuHistory.append(cpu)
        ramHistory.append(ramPercent)
        pressureHistory.append(pressure)
        if cpuHistory.count > maxSamples { cpuHistory.removeFirst() }
        if ramHistory.count > maxSamples { ramHistory.removeFirst() }
        if pressureHistory.count > maxSamples { pressureHistory.removeFirst() }
    }

    private func readPressure() -> Double {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_level", &level, &size, nil, 0) == 0 else { return 0 }
        return Double(100 - level)
    }
}
