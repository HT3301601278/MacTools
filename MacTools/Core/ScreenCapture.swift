import AppKit
import ScreenCaptureKit

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let bounds: CGRect
    var thumbnail: NSImage?
    let pid: pid_t
    let scWindow: SCWindow?
}

enum ScreenCapture {
    
    private static let excludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
        "com.apple.Spotlight",
    ]
    
    static func fetchWindows() async -> [WindowInfo] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let currentPID = ProcessInfo.processInfo.processIdentifier
            
            var results: [WindowInfo] = []
            var seenApps = Set<pid_t>()
            
            for scWindow in content.windows {
                guard let app = scWindow.owningApplication else { continue }
                let ownerPID = app.processID
                let bundleID = app.bundleIdentifier
                
                guard ownerPID != currentPID,
                      !excludedBundleIDs.contains(bundleID),
                      scWindow.frame.width > 100,
                      scWindow.frame.height > 100,
                      scWindow.isOnScreen,
                      !(scWindow.title ?? "").isEmpty else { continue }
                
                guard !seenApps.contains(ownerPID) else { continue }
                seenApps.insert(ownerPID)
                
                let ownerName = app.applicationName
                let name = scWindow.title ?? ""
                let displayName = "\(ownerName) - \(name)"
                
                var thumbnail: NSImage?
                do {
                    let filter = SCContentFilter(desktopIndependentWindow: scWindow)
                    let config = SCStreamConfiguration()
                    config.width = 400
                    config.height = Int(400 * scWindow.frame.height / scWindow.frame.width)
                    config.showsCursor = false
                    
                    let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                } catch {
                    if let runningApp = NSRunningApplication(processIdentifier: ownerPID) {
                        thumbnail = runningApp.icon
                    }
                }
                
                results.append(WindowInfo(
                    id: scWindow.windowID,
                    name: displayName,
                    ownerName: ownerName,
                    bounds: scWindow.frame,
                    thumbnail: thumbnail,
                    pid: ownerPID,
                    scWindow: scWindow
                ))
            }
            
            return results
        } catch {
            return []
        }
    }
}
