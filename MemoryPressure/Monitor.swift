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

    // Moduli (berejo se samo, ko je popup odprt)
    var gpu: Double?
    var gpuHistory: [Double] = []
    var diskFreeGB: Double = 0
    var diskUsedGB: Double = 0
    var diskPercent: Double = 0
    var netDown: Double = 0           // bajti na sekundo
    var netUp: Double = 0
    var netHistory: [Double] = []
    var fanRPM: Double?

    var hasFan: Bool { fans.count > 0 }
    var fanCount: Int { fans.count }

    @ObservationIgnored private let stats = SystemStats()
    @ObservationIgnored private let net = NetworkReader()
    @ObservationIgnored private let fans = FanReader()
    @ObservationIgnored private var modulesActive = false
    @ObservationIgnored private let maxSamples = 900   // 30 min pri vzorcu na 2 s
    @ObservationIgnored private let maxModuleSamples = 60

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

        if modulesActive { refreshModules() }
    }

    // Kliče AppDelegate ob odprtju in zaprtju popupa
    func setModulesActive(_ active: Bool) {
        modulesActive = active
        if active {
            refreshModules()
        } else {
            net.reset()
        }
    }

    private func isOn(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    private func refreshModules() {
        if isOn("moduleGPU") {
            gpu = GPUReader.utilization()
            if let g = gpu {
                gpuHistory.append(g)
                if gpuHistory.count > maxModuleSamples { gpuHistory.removeFirst() }
            }
        }
        if isOn("moduleDisk"), let d = DiskReader.read() {
            diskFreeGB = d.freeGB
            diskUsedGB = d.usedGB
            diskPercent = d.percent
        }
        if isOn("moduleNet") {
            let r = net.sample()
            netDown = r.down
            netUp = r.up
            netHistory.append(r.down)
            if netHistory.count > maxModuleSamples { netHistory.removeFirst() }
        }
        if isOn("moduleFan") {
            fanRPM = fans.rpm()
        }
    }

    private func readPressure() -> Double {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_level", &level, &size, nil, 0) == 0 else { return 0 }
        return Double(100 - level)
    }
}
