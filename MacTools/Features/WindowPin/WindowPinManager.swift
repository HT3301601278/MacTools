import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class WindowPinManager {
    
    static let shared = WindowPinManager()
    
    private var pinnedWindows: Set<CGWindowID> = []
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private init() {
        registerHotKey()
    }
    
    deinit {
        unregisterHotKey()
    }
    
    func registerHotKey() {
        unregisterHotKey()
        
        let modifiers = UserDefaults.standard.integer(forKey: "windowPinModifiers")
        let keyCode = UserDefaults.standard.integer(forKey: "windowPinKeyCode")
        
        guard keyCode != 0 else { return }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D544C53) // "MTLS"
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            DispatchQueue.main.async {
                WindowPinManager.shared.togglePinFrontWindow()
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    func togglePinFrontWindow() {
        guard AXIsProcessTrusted() else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        
        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedWindowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
              let focusedWindowRef else { return }
        
        let focusedWindow = focusedWindowRef as! AXUIElement
        
        var pidValue: pid_t = 0
        AXUIElementGetPid(focusedWindow, &pidValue)
        
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let windowInfo = windowList.first(where: {
            ($0[kCGWindowOwnerPID as String] as? Int32) == pidValue
        }),
        let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else { return }
        
        if pinnedWindows.contains(windowID) {
            unpinWindow(focusedWindow)
            pinnedWindows.remove(windowID)
        } else {
            pinWindow(focusedWindow)
            pinnedWindows.insert(windowID)
        }
    }
    
    private func pinWindow(_ window: AXUIElement) {
        let level = CGWindowLevelForKey(.floatingWindow)
        setWindowLevel(window, level: level)
    }
    
    private func unpinWindow(_ window: AXUIElement) {
        let level = CGWindowLevelForKey(.normalWindow)
        setWindowLevel(window, level: level)
    }
    
    private func setWindowLevel(_ window: AXUIElement, level: CGWindowLevel) {
        var pidValue: pid_t = 0
        AXUIElementGetPid(window, &pidValue)
        
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let windowInfo = windowList.first(where: {
            ($0[kCGWindowOwnerPID as String] as? Int32) == pidValue
        }),
        let _ = windowInfo[kCGWindowNumber as String] as? CGWindowID else { return }
        
        if let app = NSRunningApplication(processIdentifier: pidValue) {
            app.activate()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let script = """
            tell application "System Events"
                set frontmost of (first process whose unix id is \(pidValue)) to true
            end tell
            """
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
            }
        }
    }
    
    func isPinned(_ windowID: CGWindowID) -> Bool {
        pinnedWindows.contains(windowID)
    }
}
