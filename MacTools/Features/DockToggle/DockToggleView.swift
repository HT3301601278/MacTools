import SwiftUI

struct DockToggleView: View {
    @AppStorage("dockToggleEnabled") private var dockToggleEnabled = true
    @State private var hasAccessibility = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section {
                Toggle("启用 Dock 切换功能", isOn: $dockToggleEnabled)
                    .disabled(!hasAccessibility)
            } footer: {
                Text("点击 Dock 图标时，如果该应用窗口已聚焦，则最小化窗口")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
    }
}
