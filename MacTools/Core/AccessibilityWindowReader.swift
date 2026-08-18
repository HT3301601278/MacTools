import ApplicationServices
import AppKit

struct AccessibilityWindowSnapshot {
    let element: AXUIElement
    let title: String?
    let position: CGPoint
    let size: CGSize
    let role: String?
    let subrole: String?
    let isMinimized: Bool
    let isHidden: Bool
}

enum AccessibilityWindowReader {

    private static let excludedSubroles: Set<String> = [
        "AXFloatingWindow",
        "AXSystemFloatingWindow",
        "AXDecorative",
    ]

    static func windows(for pid: pid_t) -> [AccessibilityWindowSnapshot] {
        let application = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        var snapshots: [AccessibilityWindowSnapshot] = []
        snapshots.reserveCapacity(windows.count)
        for window in windows {
            if let snapshot = snapshot(for: window) {
                snapshots.append(snapshot)
            }
        }
        return snapshots
    }

    private static func visibleWindows(from windows: [AccessibilityWindowSnapshot]) -> [AccessibilityWindowSnapshot] {
        windows.filter {
            !$0.isMinimized &&
            !$0.isHidden
        }
    }

    static func userFacingWindows(from windows: [AccessibilityWindowSnapshot]) -> [AccessibilityWindowSnapshot] {
        let visibleWindows = visibleWindows(from: windows).filter { $0.role == "AXWindow" }
        let standardWindows = visibleWindows.filter {
            !excludedSubroles.contains($0.subrole ?? "")
        }

        if !standardWindows.isEmpty {
            return standardWindows
        }

        return visibleWindows.count == 1 ? visibleWindows : []
    }

    static func geometryMatches(
        _ window: AccessibilityWindowSnapshot,
        bounds: CGRect,
        tolerance: CGFloat = 60
    ) -> Bool {
        return abs(window.position.x - bounds.origin.x) <= tolerance &&
               abs(window.position.y - bounds.origin.y) <= tolerance &&
               abs(window.size.width - bounds.width) <= tolerance &&
               abs(window.size.height - bounds.height) <= tolerance
    }

    static func size(of element: AXUIElement) -> CGSize? {
        sizeAttribute(kAXSizeAttribute as CFString, from: element)
    }

    static func focusedWindow(for pid: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(pid)
        guard let value = valueAttribute(kAXFocusedWindowAttribute as CFString, from: application),
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func snapshot(for element: AXUIElement) -> AccessibilityWindowSnapshot? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, from: element),
              let size = sizeAttribute(kAXSizeAttribute as CFString, from: element) else {
            return nil
        }

        return AccessibilityWindowSnapshot(
            element: element,
            title: stringAttribute(kAXTitleAttribute as CFString, from: element),
            position: position,
            size: size,
            role: stringAttribute(kAXRoleAttribute as CFString, from: element),
            subrole: stringAttribute(kAXSubroleAttribute as CFString, from: element),
            isMinimized: boolAttribute(kAXMinimizedAttribute as CFString, from: element) ?? false,
            isHidden: boolAttribute(kAXHiddenAttribute as CFString, from: element) ?? false
        )
    }

    private static func valueAttribute(_ attribute: CFString, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value
    }

    private static func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        guard let value = valueAttribute(attribute, from: element) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func boolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool? {
        if let value = valueAttribute(attribute, from: element) as? Bool {
            return value
        }
        if let value = valueAttribute(attribute, from: element) as? NSNumber {
            return value.boolValue
        }
        return nil
    }

    private static func pointAttribute(_ attribute: CFString, from element: AXUIElement) -> CGPoint? {
        guard let value = axValueAttribute(attribute, from: element) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private static func sizeAttribute(_ attribute: CFString, from element: AXUIElement) -> CGSize? {
        guard let value = axValueAttribute(attribute, from: element) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private static func axValueAttribute(_ attribute: CFString, from element: AXUIElement) -> AXValue? {
        guard let value = valueAttribute(attribute, from: element),
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXValue.self)
    }
}
