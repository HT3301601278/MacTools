import AppKit
import SwiftUI
import ApplicationServices

struct WindowSize: Identifiable, Hashable, Codable {
    let id: UUID
    let width: Int
    let height: Int
    var label: String { "\(width)×\(height)" }

    init(id: UUID = UUID(), width: Int, height: Int) {
        self.id = id
        self.width = width
        self.height = height
    }
}

@MainActor
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

        let hostingController = NSHostingController(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "选择尺寸"
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

    func close() {
        panel?.close()
        panel = nil
        targetWindow = nil
    }

    private func resizeWindow(to size: WindowSize) {
        guard let window = targetWindow else { return }

        let axApp = AXUIElementCreateApplication(window.pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }

        let screenHeight = NSScreen.main?.frame.height ?? 0

        for axWindow in windows {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?

            guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posRef) == .success,
                  AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef) == .success else { continue }

            var axPos = CGPoint.zero
            var axSize = CGSize.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &axPos)
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &axSize)

            let scWindowTop = screenHeight - window.bounds.origin.y - window.bounds.height

            let tolerance: CGFloat = 30
            let xMatch = abs(axPos.x - window.bounds.origin.x) < tolerance
            let yMatch = abs(axPos.y - scWindowTop) < tolerance
            let sizeMatch = abs(axSize.width - window.bounds.width) < tolerance &&
                           abs(axSize.height - window.bounds.height) < tolerance

            if (xMatch && yMatch) || sizeMatch {
                if let app = NSRunningApplication(processIdentifier: window.pid) {
                    app.activate(options: [])
                }

                var newPos = CGPoint(x: 100, y: 80)
                let posValue: CFTypeRef = AXValueCreate(.cgPoint, &newPos)!
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)

                Thread.sleep(forTimeInterval: 0.1)

                var newSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
                let sizeValue: CFTypeRef = AXValueCreate(.cgSize, &newSize)!
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)

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
                .padding(.top, 20)
                .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PresetSizeStore.shared.sizes) { size in
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
        .frame(minWidth: 420, minHeight: 320)
    }
}
