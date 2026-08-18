import AppKit
import SwiftUI

@MainActor
final class WindowPickerPanel {
    static let shared = WindowPickerPanel()

    private var panel: NSPanel?
    private var loadTask: Task<Void, Never>?
    private var requestID = UUID()

    private init() {}

    func show() {
        SizePickerPanel.shared.close()
        close()

        let currentRequestID = UUID()
        requestID = currentRequestID
        loadTask = Task { [weak self] in
            do {
                let windows = try await ScreenCapture.fetchWindows()
                guard !Task.isCancelled else { return }
                self?.finishLoading(windows: windows, requestID: currentRequestID)
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishLoading(
                    windows: [],
                    requestID: currentRequestID,
                    message: "无法读取窗口，请确认屏幕录制权限已开启。"
                )
            }
        }
    }

    func close() {
        requestID = UUID()
        loadTask?.cancel()
        loadTask = nil
        panel?.close()
        panel = nil
    }

    private func finishLoading(windows: [WindowInfo], requestID: UUID, message: String? = nil) {
        guard requestID == self.requestID else { return }
        loadTask = nil

        let message = message ?? (windows.isEmpty ? "没有找到可调整的可见窗口。" : nil)
        presentPanel(with: windows, message: message)
    }

    private func presentPanel(with windows: [WindowInfo], message: String?) {
        let view = WindowPickerView(windows: windows, message: message) { selectedWindow in
            self.close()
            SizePickerPanel.shared.show(for: selectedWindow)
        } onCancel: {
            self.close()
        }

        let hostingController = NSHostingController(rootView: view)
        hostingController.sizingOptions = []

        let panelSize = NSSize(width: 760, height: 500)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "选择窗口"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.contentViewController = hostingController
        panel.setContentSize(panelSize)
        panel.centerOnVisibleScreen()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }
}

struct WindowPickerView: View {
    let windows: [WindowInfo]
    let message: String?
    let onSelect: (WindowInfo) -> Void
    let onCancel: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 250))]

    var body: some View {
        VStack(spacing: 0) {
            if let message {
                Spacer()
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(windows) { window in
                            WindowThumbnailView(window: window)
                                .onTapGesture { onSelect(window) }
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 760, minHeight: 500)
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
                            .foregroundStyle(.gray)
                    )
            }

            VStack(spacing: 2) {
                Text(window.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("\(Int(window.bounds.width)) × \(Int(window.bounds.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
