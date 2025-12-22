import AppKit
import ApplicationServices
import Combine

struct WindowSize: Identifiable, Hashable {
    let id = UUID()
    let width: Int
    let height: Int
    var label: String { "\(width)×\(height)" }
}

final class WindowResizer: ObservableObject {
    
    static let presetSizes: [WindowSize] = [
        WindowSize(width: 640, height: 360),
        WindowSize(width: 800, height: 500),
        WindowSize(width: 960, height: 540),
        WindowSize(width: 1024, height: 640),
        WindowSize(width: 1280, height: 720),
        WindowSize(width: 1280, height: 800),
        WindowSize(width: 1360, height: 765),
        WindowSize(width: 1440, height: 900),
        WindowSize(width: 1600, height: 900),
        WindowSize(width: 1600, height: 1000),
    ]
    
    @Published var runningApps: [NSRunningApplication] = []
    @Published var selectedApp: NSRunningApplication?
    @Published var customWidth: String = "1280"
    @Published var customHeight: String = "720"
    @Published var statusMessage: String = ""
    
    init() {
        refreshApps()
    }
    
    func refreshApps() {
        runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.localizedName != nil
        }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        
        if selectedApp == nil, let first = runningApps.first {
            selectedApp = first
        }
    }
    
    func resize(to size: WindowSize) {
        resize(width: size.width, height: size.height)
    }
    
    func resizeCustom() {
        guard let w = Int(customWidth), let h = Int(customHeight), w > 0, h > 0 else {
            statusMessage = "请输入有效的宽度和高度"
            return
        }
        resize(width: w, height: h)
    }
    
    private func resize(width: Int, height: Int) {
        guard AXIsProcessTrusted() else {
            statusMessage = "需要辅助功能权限"
            return
        }
        guard let app = selectedApp else {
            statusMessage = "请选择应用"
            return
        }
        
        app.activate()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement],
                  let frontWindow = windows.first else {
                self.statusMessage = "未找到窗口"
                return
            }
            
            var position = CGPoint(x: 100, y: 80)
            let positionValue: CFTypeRef = AXValueCreate(.cgPoint, &position)!
            AXUIElementSetAttributeValue(frontWindow, kAXPositionAttribute as CFString, positionValue)
            
            var size = CGSize(width: CGFloat(width), height: CGFloat(height))
            let sizeValue: CFTypeRef = AXValueCreate(.cgSize, &size)!
            AXUIElementSetAttributeValue(frontWindow, kAXSizeAttribute as CFString, sizeValue)
            
            self.statusMessage = "已调整为 \(width)×\(height)"
        }
    }
}
