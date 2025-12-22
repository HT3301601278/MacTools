import SwiftUI
import Carbon.HIToolbox

struct WindowPinView: View {
    @AppStorage("windowPinEnabled") private var windowPinEnabled = true
    @State private var isRecording = false
    @State private var currentShortcut: String = ""
    @State private var modifiers: Int = 0
    @State private var keyCode: Int = 0
    @State private var hasAccessibility = AXIsProcessTrusted()
    
    var body: some View {
        Form {
            Section {
                Toggle("启用窗口置顶功能", isOn: $windowPinEnabled)
                    .disabled(!hasAccessibility)
            } footer: {
                Text("关闭后快捷键将不生效")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷键")
                    HStack {
                        Text(currentShortcut.isEmpty ? "未设置" : currentShortcut)
                            .frame(minWidth: 120)
                            .padding(8)
                            .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        
                        Button(isRecording ? "取消" : "录制") {
                            isRecording.toggle()
                        }
                        .disabled(!hasAccessibility)
                        
                        if !currentShortcut.isEmpty {
                            Button("清除") {
                                clearShortcut()
                            }
                        }
                    }
                    
                    if isRecording {
                        Text("按下你想要的快捷键组合...")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            } footer: {
                Text("按下快捷键可将当前窗口置顶/取消置顶")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadShortcut()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
        .background(KeyRecorderView(isRecording: $isRecording, onKeyRecorded: { mods, code in
            saveShortcut(modifiers: mods, keyCode: code)
        }))
    }
    
    private func loadShortcut() {
        modifiers = UserDefaults.standard.integer(forKey: "windowPinModifiers")
        keyCode = UserDefaults.standard.integer(forKey: "windowPinKeyCode")
        
        if keyCode == 0 && modifiers == 0 {
            modifiers = cmdKey | shiftKey
            keyCode = kVK_ANSI_T
            saveShortcut(modifiers: modifiers, keyCode: keyCode)
        }
        
        currentShortcut = shortcutString(modifiers: modifiers, keyCode: keyCode)
    }
    
    private func saveShortcut(modifiers: Int, keyCode: Int) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        UserDefaults.standard.set(modifiers, forKey: "windowPinModifiers")
        UserDefaults.standard.set(keyCode, forKey: "windowPinKeyCode")
        currentShortcut = shortcutString(modifiers: modifiers, keyCode: keyCode)
        WindowPinManager.shared.registerHotKey()
        isRecording = false
    }
    
    private func clearShortcut() {
        modifiers = 0
        keyCode = 0
        UserDefaults.standard.set(0, forKey: "windowPinModifiers")
        UserDefaults.standard.set(0, forKey: "windowPinKeyCode")
        currentShortcut = ""
        WindowPinManager.shared.unregisterHotKey()
    }
    
    private func shortcutString(modifiers: Int, keyCode: Int) -> String {
        guard keyCode != 0 else { return "" }
        
        var parts: [String] = []
        if modifiers & controlKey != 0 { parts.append("⌃") }
        if modifiers & optionKey != 0 { parts.append("⌥") }
        if modifiers & shiftKey != 0 { parts.append("⇧") }
        if modifiers & cmdKey != 0 { parts.append("⌘") }
        
        let keyString = keyCodeToString(keyCode)
        parts.append(keyString)
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        let keyMap: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥",
            kVK_Delete: "⌫", kVK_Escape: "⎋",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        return keyMap[keyCode] ?? "?"
    }
}

struct KeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onKeyRecorded: (Int, Int) -> Void
    
    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.onKeyRecorded = onKeyRecorded
        return view
    }
    
    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onKeyRecorded = onKeyRecorded
    }
}

class KeyRecorderNSView: NSView {
    var isRecording = false
    var onKeyRecorded: ((Int, Int) -> Void)?
    private var monitor: Any?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupMonitor()
    }
    
    private func setupMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            let modifiers = event.modifierFlags
            var carbonMods = 0
            if modifiers.contains(.control) { carbonMods |= controlKey }
            if modifiers.contains(.option) { carbonMods |= optionKey }
            if modifiers.contains(.shift) { carbonMods |= shiftKey }
            if modifiers.contains(.command) { carbonMods |= cmdKey }
            
            if carbonMods != 0 {
                self.onKeyRecorded?(carbonMods, Int(event.keyCode))
            }
            
            return nil
        }
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
