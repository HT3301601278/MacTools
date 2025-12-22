import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasAccessibility = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section("权限") {
                HStack {
                    Text("辅助功能权限")
                    Spacer()
                    if hasAccessibility {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if AXIsProcessTrusted() {
                        Button("重启生效") {
                            let url = Bundle.main.bundleURL
                            let task = Process()
                            task.launchPath = "/usr/bin/open"
                            task.arguments = [url.path]
                            task.launch()
                            NSApp.terminate(nil)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("去授权") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            
            Section("启动") {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
    }
}
