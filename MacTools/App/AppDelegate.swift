import ApplicationServices
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "dockToggleEnabled": true,
            "windowResizerEnabled": true,
            "showInDock": false
        ])

        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        setupStatusItem()

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        refreshManagers()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshManagers()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "MacTools")
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            openMainWindow()
        }
    }

    private func openMainWindow() {
        NSApp.windows.first { $0.title == "MacTools" }?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApp.terminate(_:)), keyEquivalent: ""))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func refreshManagers() {
        DockToggleManager.shared.refresh()
        WindowResizerManager.shared.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DockToggleManager.shared.stop()
        WindowResizerManager.shared.stop()
    }
}
