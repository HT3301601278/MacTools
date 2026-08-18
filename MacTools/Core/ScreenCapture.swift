import ApplicationServices
import AppKit
import ScreenCaptureKit

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let name: String
    let nativeTitle: String?
    let bounds: CGRect
    let thumbnail: NSImage?
    let pid: pid_t
    let hasDuplicateName: Bool
}

enum ScreenCapture {

    private static let excludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
        "com.apple.Spotlight",
    ]

    static func fetchWindows() async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let canInspectAccessibility = AXIsProcessTrusted()
        var accessibilityWindowsByPID: [pid_t: [AccessibilityWindowSnapshot]] = [:]
        var results: [WindowInfo] = []

        for scWindow in content.windows {
            try Task.checkCancellation()
            guard let app = scWindow.owningApplication else { continue }

            let ownerPID = app.processID
            let bundleID = app.bundleIdentifier
            let runningApp = NSRunningApplication(processIdentifier: ownerPID)
            let applicationName = app.applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
            let ownerName = applicationName.isEmpty
                ? (runningApp?.localizedName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                : applicationName
            let windowTitle = scWindow.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let nativeTitle = windowTitle?.isEmpty == true ? nil : windowTitle

            guard ownerPID != currentPID,
                  !excludedBundleIDs.contains(bundleID),
                  scWindow.frame.width > 100,
                  scWindow.frame.height > 100,
                  scWindow.windowLayer == 0,
                  runningApp?.isTerminated != true,
                  !ownerName.isEmpty else { continue }

            if nativeTitle == nil {
                guard canInspectAccessibility,
                      let runningApp,
                      !runningApp.isHidden,
                      runningApp.activationPolicy != .prohibited else { continue }

                let axWindows: [AccessibilityWindowSnapshot]
                if let cachedWindows = accessibilityWindowsByPID[ownerPID] {
                    axWindows = cachedWindows
                } else {
                    let windows = AccessibilityWindowReader.windows(for: ownerPID)
                    accessibilityWindowsByPID[ownerPID] = windows
                    axWindows = windows
                }
                let candidateWindows = AccessibilityWindowReader.userFacingWindows(from: axWindows)
                let geometryMatches = candidateWindows.filter {
                    AccessibilityWindowReader.geometryMatches($0, bounds: scWindow.frame)
                }
                guard !geometryMatches.isEmpty || (candidateWindows.count == 1 && axWindows.count == 1) else {
                    continue
                }
            }

            var thumbnail: NSImage?
            do {
                let filter = SCContentFilter(desktopIndependentWindow: scWindow)
                let config = SCStreamConfiguration()
                config.width = 400
                config.height = max(1, Int(400 * scWindow.frame.height / scWindow.frame.width))
                config.showsCursor = false

                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            } catch {
                try Task.checkCancellation()
                thumbnail = runningApp?.icon
            }

            let displayName = nativeTitle.map { "\(ownerName) - \($0)" } ?? ownerName
            results.append(WindowInfo(
                id: scWindow.windowID,
                name: displayName,
                nativeTitle: nativeTitle,
                bounds: scWindow.frame,
                thumbnail: thumbnail,
                pid: ownerPID,
                hasDuplicateName: false
            ))
        }

        return disambiguated(results)
    }

    private static func disambiguated(_ windows: [WindowInfo]) -> [WindowInfo] {
        let groups = Dictionary(grouping: windows, by: \.name)
        var namesByID: [CGWindowID: String] = [:]

        for group in groups.values where group.count > 1 {
            let ordered = group.sorted {
                if $0.bounds.minY != $1.bounds.minY {
                    return $0.bounds.minY < $1.bounds.minY
                }
                if $0.bounds.minX != $1.bounds.minX {
                    return $0.bounds.minX < $1.bounds.minX
                }
                return $0.id < $1.id
            }

            for (index, window) in ordered.enumerated() {
                namesByID[window.id] = "\(window.name) #\(index + 1)"
            }
        }

        return windows.map { window in
            guard let name = namesByID[window.id] else { return window }
            return WindowInfo(
                id: window.id,
                name: name,
                nativeTitle: window.nativeTitle,
                bounds: window.bounds,
                thumbnail: window.thumbnail,
                pid: window.pid,
                hasDuplicateName: true
            )
        }
    }
}
