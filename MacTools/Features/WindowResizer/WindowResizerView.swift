import SwiftUI

struct WindowResizerView: View {
    @AppStorage("windowResizerEnabled") private var windowResizerEnabled = true
    @StateObject private var resizer = WindowResizer()
    @State private var hasAccessibility = AXIsProcessTrusted()
    
    private let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        Form {
            Section {
                Toggle("启用窗口调整功能", isOn: $windowResizerEnabled)
                    .disabled(!hasAccessibility)
            }
            
            Section("目标应用") {
                HStack {
                    Picker("选择应用", selection: $resizer.selectedApp) {
                        ForEach(resizer.runningApps, id: \.processIdentifier) { app in
                            Text(app.localizedName ?? "Unknown")
                                .tag(app as NSRunningApplication?)
                        }
                    }
                    .labelsHidden()
                    
                    Button(action: resizer.refreshApps) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            
            Section("预设尺寸") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(WindowResizer.presetSizes) { size in
                        Button(size.label) {
                            resizer.resize(to: size)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasAccessibility || !windowResizerEnabled)
                    }
                }
            }
            
            Section("自定义尺寸") {
                HStack {
                    TextField("宽", text: $resizer.customWidth)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("×")
                    TextField("高", text: $resizer.customHeight)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Button("应用") {
                        resizer.resizeCustom()
                    }
                    .disabled(!hasAccessibility || !windowResizerEnabled)
                }
            }
            
            if !resizer.statusMessage.isEmpty {
                Section {
                    Text(resizer.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
    }
}
