import SwiftUI

struct MenuBarView: View {
    @AppStorage("dockToggleEnabled") private var dockToggleEnabled = true
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("打开主窗口") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            
            Divider()
            
            Toggle("Dock 切换", isOn: $dockToggleEnabled)
            
            Divider()
            
            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 160)
    }
}
