import ApplicationServices
import AppKit
import CoreGraphics
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasScreenCapture = CGPreflightScreenCaptureAccess()
    @AppStorage("showInDock") private var showInDock = false

    var body: some View {
        Form {
            Section("权限") {
                HStack {
                    Text("辅助功能权限")
                    Spacer()
                    if hasAccessibility {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("去授权") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                self.openPrivacySettings("Privacy_Accessibility")
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
                            .foregroundStyle(.green)
                    } else {
                        Button("去授权") {
                            hasScreenCapture = CGRequestScreenCaptureAccess()
                            if !hasScreenCapture {
                                openPrivacySettings("Privacy_ScreenCapture")
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
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        hasAccessibility = AXIsProcessTrusted()
        hasScreenCapture = CGPreflightScreenCaptureAccess()
    }

    private func openPrivacySettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
