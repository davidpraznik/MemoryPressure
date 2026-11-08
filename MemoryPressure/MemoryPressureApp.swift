import SwiftUI
import AppKit

@main
struct MemoryPressureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: PopupPanel!
    private var host: NSHostingView<PopupView>!
    private var clickMonitor: Any?
    private let monitor = Monitor()
    private var timer: Timer?

    private var alertPanel: PopupPanel?
    private var alertHideWork: DispatchWorkItem?
    private var alertArmed = true
    private var lastAlert: Date?

    // Meji se berejo iz nastavitev (privzeto 90 in 85)
    private var cpuLimit: Double {
        UserDefaults.standard.object(forKey: "cpuLimit") as? Double ?? 90
    }
    private var pressureLimit: Double {
        UserDefaults.standard.object(forKey: "pressureLimit") as? Double ?? 85
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        host = NSHostingView(rootView: PopupView(monitor: monitor))
        panel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = host

        NotificationCenter.default.addObserver(forName: .popupContentChanged,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resizePanel() }
        }

        update()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func togglePanel() {
        if panel.isVisible { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let button = statusItem.button, let window = button.window else { return }
        monitor.setModulesActive(true)
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let size = host.fittingSize
        let screen = window.screen?.visibleFrame ?? .zero
        var x = buttonFrame.midX - size.width / 2
        x = min(max(x, screen.minX + 8), screen.maxX - size.width - 8)
        let y = buttonFrame.minY - size.height - 6
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func hidePanel() {
        monitor.setModulesActive(false)
        panel.orderOut(nil)
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
    }

    // Ob menjavi vsebine (nastavitve, jezik) se panel prilagodi višini, zgornji rob ostane na mestu
    private func resizePanel() {
        guard panel.isVisible else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.host.layoutSubtreeIfNeeded()
            let size = self.host.fittingSize
            let old = self.panel.frame
            let frame = NSRect(x: old.minX, y: old.maxY - size.height,
                               width: size.width, height: size.height)
            self.panel.setFrame(frame, display: true, animate: false)
        }
    }

    private func quit(_ app: AppUsage) {
        for running in NSWorkspace.shared.runningApplications where running.bundleURL?.path == app.id {
            running.terminate()
        }
    }

    private func showAlert(pressure: Double) {
        hideAlert()
        let top = monitor.apps.first
        let card = AlertCard(
            pressure: pressure,
            appName: top?.name,
            appBytes: top?.bytes,
            onQuit: { [weak self] in
                if let top { self?.quit(top) }
                self?.hideAlert()
            },
            onClear: { [weak self] in
                self?.hideAlert()
                Purger.run()
            }
        )
        let alertHost = NSHostingView(rootView: card)
        let size = alertHost.fittingSize
        let alert = PopupPanel(contentRect: NSRect(origin: .zero, size: size),
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        alert.isFloatingPanel = true
        alert.level = .statusBar
        alert.backgroundColor = .clear
        alert.isOpaque = false
        alert.hasShadow = true
        alert.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alert.contentView = alertHost
        if let screen = NSScreen.main?.visibleFrame {
            alert.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 16,
                                         y: screen.maxY - size.height - 16))
        }
        alert.orderFrontRegardless()
        alertPanel = alert

        let work = DispatchWorkItem { [weak self] in self?.hideAlert() }
        alertHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    private func hideAlert() {
        alertHideWork?.cancel()
        alertHideWork = nil
        alertPanel?.orderOut(nil)
        alertPanel = nil
    }

    private func checkAlert() {
        let defaults = UserDefaults.standard
        let remind = defaults.object(forKey: "remindEnabled") as? Bool ?? true
        let autoClear = defaults.object(forKey: "autoClearEnabled") as? Bool ?? false
        let limit = pressureLimit

        if monitor.pressure < limit - 5 { alertArmed = true }
        guard remind || autoClear, alertArmed, monitor.pressure >= limit else { return }
        if let last = lastAlert, Date().timeIntervalSince(last) < 600 { return }
        alertArmed = false
        lastAlert = Date()

        let pressure = monitor.pressure
        if autoClear {
            Purger.runSilently { [weak self] ok in
                if !ok && remind { self?.showAlert(pressure: pressure) }
            }
        } else {
            showAlert(pressure: pressure)
        }
    }

    private func update() {
        monitor.refresh()
        let isSlovene = UserDefaults.standard.string(forKey: "language") == "si"
        let locale = Locale(identifier: isSlovene ? "sl_SI" : "en_US")
        let cpuText = String(format: "%.0f %%", locale: locale, monitor.cpu)
        let ramText = String(format: "%.1f GB", locale: locale, monitor.ramUsedGB)

        let hotColor = Theme.warnNS
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        let title = NSMutableAttributedString()
        func part(_ text: String, hot: Bool) {
            title.append(NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: hot ? hotColor : NSColor.labelColor
            ]))
        }
        part(cpuText, hot: monitor.cpu >= cpuLimit)
        part("  ", hot: false)
        part(ramText, hot: monitor.pressure >= pressureLimit)
        statusItem.button?.attributedTitle = title

        checkAlert()
    }
}
