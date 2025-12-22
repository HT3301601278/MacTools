import AppKit
import ApplicationServices

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let bounds: CGRect
    let appIcon: NSImage?
    let pid: pid_t
}

final class WindowPickerPanel {
    static let shared = WindowPickerPanel()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<WindowPickerView>?
    
    private init() {}
    
    func show() {
        close()
        
        let windows = fetchWindows()
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
    
    func close() {
        panel?.close()
        panel = nil
        hostingView = nil
    }
    
    private func fetchWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var results: [WindowInfo] = []
        let currentPID = ProcessInfo.processInfo.processIdentifier
        var seenApps = Set<pid_t>()
        
        for info in windowList {
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != currentPID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"],
                  w > 50, h > 50 else { continue }
            
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            
            // 每个应用只取一个窗口
            guard !seenApps.contains(ownerPID) else { continue }
            seenApps.insert(ownerPID)
            
            let name = info[kCGWindowName as String] as? String ?? ""
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            let bounds = CGRect(x: x, y: y, width: w, height: h)
            
            // 获取应用图标
            var appIcon: NSImage?
            if let app = NSRunningApplication(processIdentifier: ownerPID) {
                appIcon = app.icon
            }
            
            let displayName = name.isEmpty ? ownerName : "\(ownerName) - \(name)"
            
            results.append(WindowInfo(
                id: windowID,
                name: displayName,
                ownerName: ownerName,
                bounds: bounds,
                appIcon: appIcon,
                pid: ownerPID
            ))
        }
        
        return results
    }
}

import SwiftUI

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
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                    .frame(width: 64, height: 64)
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
