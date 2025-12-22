import SwiftUI

struct WindowResizerView: View {
    @AppStorage("windowResizerEnabled") private var windowResizerEnabled = true
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var isRecordingShortcut = false
    @State private var shortcutDisplay = WindowResizerManager.shared.shortcutDescription
    
    private let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        Form {
            Section {
                Toggle("启用窗口调整功能", isOn: $windowResizerEnabled)
                    .disabled(!hasAccessibility)
                    .onChange(of: windowResizerEnabled) { _, enabled in
                        if enabled {
                            WindowResizerManager.shared.start()
                        } else {
                            WindowResizerManager.shared.stop()
                        }
                    }
            } footer: {
                Text("按下快捷键后会弹出窗口选择器，选择窗口后再选择目标尺寸")
                    .foregroundStyle(.secondary)
            }
            
            Section("快捷键") {
                HStack {
                    Text("触发快捷键")
                    Spacer()
                    
                    if isRecordingShortcut {
                        Text("按下新快捷键...")
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                    } else {
                        Button(shortcutDisplay) {
                            startRecording()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Section("预设尺寸") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(presetSizes) { size in
                        Text(size.label)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
            shortcutDisplay = WindowResizerManager.shared.shortcutDescription
        }
    }
    
    private func startRecording() {
        isRecordingShortcut = true
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            let hasModifier = event.modifierFlags.contains(.command) ||
                              event.modifierFlags.contains(.control) ||
                              event.modifierFlags.contains(.option)
            
            if hasModifier {
                WindowResizerManager.shared.keyCode = event.keyCode
                WindowResizerManager.shared.modifiers = modifiers
                WindowResizerManager.shared.restart()
                
                DispatchQueue.main.async {
                    self.shortcutDisplay = WindowResizerManager.shared.shortcutDescription
                    self.isRecordingShortcut = false
                }
                return nil
            }
            
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    self.isRecordingShortcut = false
                }
                return nil
            }
            
            return event
        }
    }
}
