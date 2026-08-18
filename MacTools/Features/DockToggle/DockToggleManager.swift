import ApplicationServices
import AppKit

final class DockToggleManager {

    static let shared = DockToggleManager()
    private var mouseDownMonitor: GlobalEventMonitor?
    private var mouseUpMonitor: GlobalEventMonitor?
    private var mouseDraggedMonitor: GlobalEventMonitor?
    private var pendingClick: PendingDockClick?
    private var pendingActionID: UUID?

    private struct PendingDockClick {
        let app: NSRunningApplication
        let windowCountBefore: Int
    }

    private init() {}

    func refresh() {
        guard UserDefaults.standard.bool(forKey: "dockToggleEnabled"), AXIsProcessTrusted() else {
            stop()
            return
        }
        start()
    }

    private func start() {
        guard mouseDownMonitor == nil else { return }

        let mouseDownMonitor = GlobalEventMonitor(mask: .leftMouseDown) { [weak self] _ in
            self?.handleMouseDown()
        }
        let mouseUpMonitor = GlobalEventMonitor(mask: .leftMouseUp) { [weak self] _ in
            self?.handleMouseUp()
        }
        let mouseDraggedMonitor = GlobalEventMonitor(mask: .leftMouseDragged) { [weak self] _ in
            self?.pendingClick = nil
        }

        guard mouseDownMonitor.start(),
              mouseUpMonitor.start(),
              mouseDraggedMonitor.start() else { return }

        self.mouseDownMonitor = mouseDownMonitor
        self.mouseUpMonitor = mouseUpMonitor
        self.mouseDraggedMonitor = mouseDraggedMonitor
    }

    func stop() {
        pendingActionID = nil
        mouseDownMonitor?.stop()
        mouseUpMonitor?.stop()
        mouseDraggedMonitor?.stop()
        mouseDownMonitor = nil
        mouseUpMonitor = nil
        mouseDraggedMonitor = nil
        pendingClick = nil
    }

    private func handleMouseDown() {
        pendingClick = nil
        pendingActionID = nil

        guard UserDefaults.standard.bool(forKey: "dockToggleEnabled") else { return }
        guard AXIsProcessTrusted() else { return }

        let location = NSEvent.mouseLocation

        guard let clickedBundleID = bundleIdentifierAtDockPosition(location) else { return }

        guard let app = NSWorkspace.shared.frontmostApplication,
              let frontBundleID = app.bundleIdentifier,
              frontBundleID != Bundle.main.bundleIdentifier,
              frontBundleID != "com.apple.dock",
              clickedBundleID == frontBundleID else { return }

        let windowCountBefore = visibleWindowCount(app)

        if windowCountBefore > 0 {
            pendingClick = PendingDockClick(
                app: app,
                windowCountBefore: windowCountBefore
            )
        }
    }

    private func handleMouseUp() {
        guard let pending = pendingClick else { return }
        pendingClick = nil

        let app = pending.app
        let windowCountBefore = pending.windowCountBefore
        let actionID = UUID()
        pendingActionID = actionID

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.pendingActionID == actionID else { return }
            self.pendingActionID = nil
            guard UserDefaults.standard.bool(forKey: "dockToggleEnabled"), AXIsProcessTrusted() else { return }

            let windowCountAfter = self.visibleWindowCount(app)
            if NSWorkspace.shared.frontmostApplication == app,
               windowCountAfter <= windowCountBefore {
                self.minimizeFocusedWindow(of: app)
            }
        }
    }

    private func bundleIdentifierAtDockPosition(_ location: NSPoint) -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        guard let screen = NSScreen.main else { return nil }
        let flippedY = screen.frame.maxY - location.y

        var elementRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(flippedY), &elementRef) == .success,
              let element = elementRef else { return nil }

        return extractBundleID(from: element)
    }

    private func extractBundleID(from element: AXUIElement) -> String? {
        var urlRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &urlRef) == .success {
            var url: URL?
            if let nsURL = urlRef as? NSURL {
                url = nsURL as URL
            } else if let urlString = urlRef as? String {
                url = URL(string: urlString)
            }
            if let bundleID = url.flatMap({ Bundle(url: $0)?.bundleIdentifier }) {
                return bundleID
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
        AccessibilityWindowReader.userFacingWindows(
            from: AccessibilityWindowReader.windows(for: app.processIdentifier)
        ).count
    }

    private func minimizeFocusedWindow(of app: NSRunningApplication) {
        guard let focusedWindow = AccessibilityWindowReader.focusedWindow(for: app.processIdentifier) else { return }
        _ = AXUIElementSetAttributeValue(focusedWindow, kAXMinimizedAttribute as CFString, true as CFTypeRef)
    }
}
