import AppKit
import Carbon

final class WindowResizerManager {
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
    
    func restart() {
        stop()
        start()
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
        var parts: [String] = []
        if modifiers.contains(.maskControl) { parts.append("⌃") }
        if modifiers.contains(.maskAlternate) { parts.append("⌥") }
        if modifiers.contains(.maskShift) { parts.append("⇧") }
        if modifiers.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
    
    private func keyCodeToString(_ code: UInt16) -> String {
        let mapping: [UInt16: String] = [
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
            UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
            UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
            UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
            UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
            UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
            UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
            UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
            UInt16(kVK_ANSI_9): "9",
            UInt16(kVK_Space): "Space", UInt16(kVK_Return): "↩",
            UInt16(kVK_Tab): "⇥", UInt16(kVK_Escape): "⎋",
        ]
        return mapping[code] ?? "?"
    }
}
