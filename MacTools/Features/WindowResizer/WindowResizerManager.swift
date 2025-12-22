import AppKit
import Carbon

final class WindowResizerManager: FeatureManager {
    static let shared = WindowResizerManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // 快捷键配置
    var keyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(keyCode), forKey: "windowResizerKeyCode") }
    }
    var modifiers: CGEventFlags {
        didSet { UserDefaults.standard.set(modifiers.rawValue, forKey: "windowResizerModifiers") }
    }
    
    private init() {
        keyCode = UInt16(UserDefaults.standard.integer(forKey: "windowResizerKeyCode"))
        let storedModifiers = UserDefaults.standard.integer(forKey: "windowResizerModifiers")
        modifiers = storedModifiers != 0 ? CGEventFlags(rawValue: UInt64(storedModifiers)) : [.maskCommand, .maskShift]
        
        // 默认快捷键: ⌘⇧W
        if keyCode == 0 {
            keyCode = UInt16(kVK_ANSI_W)
        }
    }
    
    func start() {
        guard eventTap == nil else { return }
        guard UserDefaults.standard.bool(forKey: "windowResizerEnabled") else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, _ in
                WindowResizerManager.shared.handleEvent(type: type, event: event)
            },
            userInfo: nil
        )
        
        guard let tap = eventTap else { return }
        
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
    

    
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }
        guard UserDefaults.standard.bool(forKey: "windowResizerEnabled") else {
            return Unmanaged.passRetained(event)
        }
        
        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventModifiers = event.flags
        
        // 检查修饰键匹配
        let requiredMods: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        let currentMods = eventModifiers.intersection(requiredMods)
        let targetMods = modifiers.intersection(requiredMods)
        
        if eventKeyCode == keyCode && currentMods == targetMods {
            DispatchQueue.main.async {
                WindowPickerPanel.shared.show()
            }
            return nil // 消费掉这个事件
        }
        
        return Unmanaged.passRetained(event)
    }
    
    var shortcutDescription: String {
        KeyCodeUtils.shortcutDescription(keyCode: keyCode, modifiers: modifiers)
    }
}
