import AppKit
import ApplicationServices

final class DockToggleManager: FeatureManager {

    static let shared = DockToggleManager()
    private var eventMonitor: GlobalEventMonitor?

    private init() {}

    func start() {
        eventMonitor = GlobalEventMonitor(mask: .leftMouseDown) { [weak self] event in
            self?.handleGlobalClick(event)
        }
        eventMonitor?.start()
    }

    func stop() {
        eventMonitor?.stop()
        eventMonitor = nil
    }

    private func handleGlobalClick(_ event: NSEvent) {
        guard UserDefaults.standard.bool(forKey: "dockToggleEnabled") else { return }
        guard AXIsProcessTrusted() else { return }

        let location = NSEvent.mouseLocation

        guard let clickedBundleId = bundleIdentifierAtDockPosition(location) else { return }

        guard let app = NSWorkspace.shared.frontmostApplication,
              let frontBundleId = app.bundleIdentifier,
              frontBundleId != Bundle.main.bundleIdentifier,
              frontBundleId != "com.apple.dock",
              clickedBundleId == frontBundleId else { return }

        let windowCountBefore = visibleWindowCount(app)

        if windowCountBefore > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let windowCountAfter = self.visibleWindowCount(app)
                if NSWorkspace.shared.frontmostApplication == app,
                   windowCountAfter <= windowCountBefore {
                    self.minimizeFocusedWindow(of: app)
                }
            }
        }
    }

    private func bundleIdentifierAtDockPosition(_ location: NSPoint) -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        guard let screen = NSScreen.main else { return nil }
        let flippedY = screen.frame.height - location.y

        var elementRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(flippedY), &elementRef) == .success,
              let element = elementRef else { return nil }

        return extractBundleId(from: element)
    }

    private func extractBundleId(from element: AXUIElement) -> String? {
        var urlRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &urlRef) == .success {
            var url: URL?
            if let nsURL = urlRef as? NSURL {
                url = nsURL as URL
            } else if let urlString = urlRef as? String {
                url = URL(string: urlString)
            }
            if let bundleId = url.flatMap({ Bundle(url: $0)?.bundleIdentifier }) {
                return bundleId
            }
        }

        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String,
           title == "废纸篓" || title == "Trash" {
            return "com.apple.finder"
        }

        return nil
    }

    private func visibleWindowCount(_ app: NSRunningApplication) -> Int {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return 0 }

        var count = 0
        for window in windows {
            var minimizedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
               let minimized = minimizedRef as? Bool, !minimized {
                count += 1
            }
        }
        return count
    }

    private func minimizeFocusedWindow(of app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
              let focusedWindowRef else { return }
        let focusedWindow = focusedWindowRef as! AXUIElement
        AXUIElementSetAttributeValue(focusedWindow, kAXMinimizedAttribute as CFString, true as CFTypeRef)
    }
}
