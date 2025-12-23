import AppKit
import SwiftUI

@MainActor
final class WindowPickerPanel {
    static let shared = WindowPickerPanel()
    
    private var panel: NSPanel?
    
    private init() {}
    
    func show() {
        close()
        
        Task {
            let windows = await ScreenCapture.fetchWindows()
            guard !windows.isEmpty else { return }
            
            await MainActor.run {
                self.presentPanel(with: windows)
            }
        }
    }
    
    func close() {
        panel?.close()
        panel = nil
    }
    
    @MainActor
    private func presentPanel(with windows: [WindowInfo]) {
        let view = WindowPickerView(windows: windows) { selectedWindow in
            self.close()
            SizePickerPanel.shared.show(for: selectedWindow)
        } onCancel: {
            self.close()
        }
        
        let hostingController = NSHostingController(rootView: view)
        
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
        panel.contentViewController = hostingController
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.centerOnVisibleScreen()
        DispatchQueue.main.async { [weak panel] in
            panel?.centerOnVisibleScreen()
        }
        self.panel = panel
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
