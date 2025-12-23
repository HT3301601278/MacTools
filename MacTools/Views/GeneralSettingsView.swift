import SwiftUI
import ServiceManagement
import ScreenCaptureKit

struct GeneralSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasScreenCapture = false
    @AppStorage("showInDock") private var showInDock = false

    var body: some View {
        Form {
            Section("权限") {
                HStack {
                    Text("辅助功能权限")
                    Spacer()
                    if hasAccessibility {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
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
                
                HStack {
                    Text("屏幕录制权限")
                    Spacer()
                    if hasScreenCapture {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("去授权") {
                            Task {
                                do {
                                    _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                                    hasScreenCapture = true
                                } catch {
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                                }
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
                
                Toggle("在程序坞显示图标", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
            checkScreenCapturePermission()
        }
        .onAppear {
            checkScreenCapturePermission()
        }
    }
    
    private func checkScreenCapturePermission() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                hasScreenCapture = true
            } catch {
                hasScreenCapture = false
            }
        }
    }
}
