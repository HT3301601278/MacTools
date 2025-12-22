import AppKit
import ApplicationServices
import ScreenCaptureKit
import SwiftUI

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let bounds: CGRect
    var thumbnail: NSImage?
    let pid: pid_t
    let scWindow: SCWindow?
}

@MainActor
final class WindowPickerPanel {
    static let shared = WindowPickerPanel()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<WindowPickerView>?
    
    private init() {}
    
    func show() {
        close()
        
        Task {
            let windows = await fetchWindows()
            guard !windows.isEmpty else { return }
            
            let view = WindowPickerView(windows: windows) { selectedWindow in
                self.close()
                SizePickerPanel.shared.show(for: selectedWindow)
            } onCancel: {
                self.close()
            }
            
            let hostingView = NSHostingView(rootView: view)
            self.hostingView = hostingView
            
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "选择窗口"
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.level = .floating
            panel.contentView = hostingView
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            self.panel = panel
        }
    }
    
    func close() {
        panel?.close()
        panel = nil
        hostingView = nil
    }
    
    private func fetchWindows() async -> [WindowInfo] {
        // 需要过滤的系统应用 bundle ID
        let excludedBundleIDs: Set<String> = [
            "com.apple.dock",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
            "com.apple.WindowManager",
            "com.apple.Spotlight",
        ]
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let currentPID = ProcessInfo.processInfo.processIdentifier
            
            var results: [WindowInfo] = []
            var seenApps = Set<pid_t>()
            
            for scWindow in content.windows {
                guard let app = scWindow.owningApplication else { continue }
                let ownerPID = app.processID
                let bundleID = app.bundleIdentifier
                
                // 过滤条件
                guard ownerPID != currentPID,
                      !excludedBundleIDs.contains(bundleID),
                      scWindow.frame.width > 100,
                      scWindow.frame.height > 100,
                      scWindow.isOnScreen,
                      !(scWindow.title ?? "").isEmpty else { continue }
                
                // 每个应用只取一个窗口
                guard !seenApps.contains(ownerPID) else { continue }
                seenApps.insert(ownerPID)
                
                let ownerName = app.applicationName
                let name = scWindow.title ?? ""
                let displayName = "\(ownerName) - \(name)"
                
                // 截取窗口缩略图
                var thumbnail: NSImage?
                do {
                    let filter = SCContentFilter(desktopIndependentWindow: scWindow)
                    let config = SCStreamConfiguration()
                    config.width = 400
                    config.height = Int(400 * scWindow.frame.height / scWindow.frame.width)
                    config.showsCursor = false
                    
                    let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                } catch {
                    // 截图失败时使用应用图标
                    if let app = NSRunningApplication(processIdentifier: ownerPID) {
                        thumbnail = app.icon
                    }
                }
                
                results.append(WindowInfo(
                    id: scWindow.windowID,
                    name: displayName,
                    ownerName: ownerName,
                    bounds: scWindow.frame,
                    thumbnail: thumbnail,
                    pid: ownerPID,
                    scWindow: scWindow
                ))
            }
            
            return results
        } catch {
            return []
        }
    }
}

struct WindowPickerView: View {
    let windows: [WindowInfo]
    let onSelect: (WindowInfo) -> Void
    let onCancel: () -> Void
    
    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 250))]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(windows) { window in
                        WindowThumbnailView(window: window)
                            .onTapGesture { onSelect(window) }
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct WindowThumbnailView: View {
    let window: WindowInfo
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "macwindow")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            Text(window.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}
