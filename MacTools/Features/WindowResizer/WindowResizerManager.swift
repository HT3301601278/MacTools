import ApplicationServices
import AppKit
import Carbon

final class WindowResizerManager {
    static let shared = WindowResizerManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var isRecordingShortcut = false

    var keyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(keyCode), forKey: "windowResizerKeyCode") }
    }
    var modifiers: CGEventFlags {
        didSet { UserDefaults.standard.set(modifiers.rawValue, forKey: "windowResizerModifiers") }
    }

    private init() {
        let defaults = UserDefaults.standard
        if let storedKey = defaults.object(forKey: "windowResizerKeyCode") as? Int {
            keyCode = UInt16(storedKey)
        } else {
            keyCode = UInt16(kVK_ANSI_W)
        }

        if let storedModifiers = defaults.object(forKey: "windowResizerModifiers") as? Int {
            modifiers = CGEventFlags(rawValue: UInt64(storedModifiers))
        } else {
            modifiers = [.maskCommand, .maskShift]
        }
    }

    func refresh() {
        guard UserDefaults.standard.bool(forKey: "windowResizerEnabled"), AXIsProcessTrusted() else {
            stop()
            return
        }
        start()
    }

    private func start() {
        guard eventTap == nil else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, _ in
                WindowResizerManager.shared.handleEvent(type: type, event: event)
            },
            userInfo: nil
        ) else { return }

        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return nil
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        guard !isRecordingShortcut else { return Unmanaged.passUnretained(event) }
        guard UserDefaults.standard.bool(forKey: "windowResizerEnabled"), AXIsProcessTrusted() else {
            return Unmanaged.passUnretained(event)
        }

        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventModifiers = event.flags

        let requiredMods: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        let currentMods = eventModifiers.intersection(requiredMods)
        let targetMods = modifiers.intersection(requiredMods)

        if eventKeyCode == keyCode && currentMods == targetMods {
            DispatchQueue.main.async {
                WindowPickerPanel.shared.show()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    var shortcutDescription: String {
        KeyCodeUtils.shortcutDescription(keyCode: keyCode, modifiers: modifiers)
    }
}
