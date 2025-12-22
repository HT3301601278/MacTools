import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "dockToggleEnabled": true,
            "windowResizerEnabled": true
        ])
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        DockToggleManager.shared.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        DockToggleManager.shared.stop()
    }
}
