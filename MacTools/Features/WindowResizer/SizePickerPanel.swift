import AppKit
import SwiftUI
import ApplicationServices

final class SizePickerPanel {
    static let shared = SizePickerPanel()
    
    private var panel: NSPanel?
    private var targetWindow: WindowInfo?
    
    private init() {}
    
    func show(for window: WindowInfo) {
        close()
        targetWindow = window
        
        let view = SizePickerView(windowName: window.name) { size in
            self.resizeWindow(to: size)
            self.close()
        } onCancel: {
            self.close()
        }
        
        let hostingView = NSHostingView(rootView: view)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "选择尺寸"
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
        targetWindow = nil
    }
    
    private func resizeWindow(to size: WindowSize) {
        guard let window = targetWindow else { return }
        
        // 通过 AX API 调整窗口大小
        let axApp = AXUIElementCreateApplication(window.pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }
        
        // 找到匹配的窗口
        for axWindow in windows {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            
            guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posRef) == .success,
                  AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef) == .success else { continue }
            
            var pos = CGPoint.zero
            var sz = CGSize.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &sz)
            
            // 匹配位置和大小
            let tolerance: CGFloat = 10
            if abs(pos.x - window.bounds.origin.x) < tolerance &&
               abs(pos.y - window.bounds.origin.y) < tolerance {
                
                // 设置新大小
                var newSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
                let sizeValue: CFTypeRef = AXValueCreate(.cgSize, &newSize)!
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
                
                // 可选：调整位置到屏幕左上角
                var newPos = CGPoint(x: 100, y: 80)
                let posValue: CFTypeRef = AXValueCreate(.cgPoint, &newPos)!
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
                
                break
            }
        }
    }
}

struct SizePickerView: View {
    let windowName: String
    let onSelect: (WindowSize) -> Void
    let onCancel: () -> Void
    
    private let columns = [GridItem(.adaptive(minimum: 100))]
    
    var body: some View {
        VStack(spacing: 0) {
            Text(windowName)
                .font(.headline)
                .lineLimit(1)
                .padding(.top, 16)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(WindowResizer.presetSizes) { size in
                        Button(size.label) {
                            onSelect(size)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
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
        .frame(minWidth: 350, minHeight: 280)
    }
}
