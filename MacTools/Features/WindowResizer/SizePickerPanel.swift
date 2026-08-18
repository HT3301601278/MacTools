import ApplicationServices
import AppKit
import SwiftUI

@MainActor
final class SizePickerPanel {
    static let shared = SizePickerPanel()

    private enum ResizeError: LocalizedError {
        case accessibilityUnavailable
        case windowsUnavailable
        case windowNotFound
        case ambiguousWindow
        case screenUnavailable
        case unableToSetSize
        case unableToSetPosition

        var errorDescription: String? {
            switch self {
            case .accessibilityUnavailable:
                return "需要辅助功能权限才能调整窗口。"
            case .windowsUnavailable:
                return "无法读取目标应用的窗口。"
            case .windowNotFound:
                return "目标窗口已变化，请重新选择。"
            case .ambiguousWindow:
                return "无法唯一识别目标窗口，请重新选择。"
            case .screenUnavailable:
                return "无法确定屏幕位置。"
            case .unableToSetSize:
                return "目标窗口不支持调整到该尺寸。"
            case .unableToSetPosition:
                return "窗口尺寸已调整，但无法移动到屏幕中央。"
            }
        }
    }

    private var panel: NSPanel?

    private init() {}

    func show(for window: WindowInfo) {
        close()

        let view = SizePickerView(windowName: window.name) { size in
            let errorMessage = self.resizeWindow(to: size, target: window)
            if errorMessage == nil {
                self.close()
            }
            return errorMessage
        } onCancel: {
            self.close()
        }

        let hostingController = NSHostingController(rootView: view)
        hostingController.sizingOptions = []

        let panelSize = NSSize(width: 520, height: 420)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "选择尺寸"
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

    func close() {
        panel?.close()
        panel = nil
    }

    private func resizeWindow(to size: WindowSize, target: WindowInfo) -> String? {
        do {
            try performResize(to: size, target: target)
            return nil
        } catch let error as ResizeError {
            return error.localizedDescription
        } catch {
            return "调整窗口失败，请重试。"
        }
    }

    private func performResize(to size: WindowSize, target: WindowInfo) throws {
        guard AXIsProcessTrusted() else { throw ResizeError.accessibilityUnavailable }

        let snapshots = AccessibilityWindowReader.windows(for: target.pid)
        guard !snapshots.isEmpty else { throw ResizeError.windowsUnavailable }
        let window = try matchingWindow(for: target, in: snapshots)

        NSRunningApplication(processIdentifier: target.pid)?.activate(options: [])

        var requestedSize = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
        guard let sizeValue = AXValueCreate(.cgSize, &requestedSize),
              AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sizeValue as CFTypeRef) == .success else {
            throw ResizeError.unableToSetSize
        }

        let actualSize = AccessibilityWindowReader.size(of: window.element) ?? requestedSize
        guard let screen = NSScreen.main else {
            throw ResizeError.screenUnavailable
        }

        var centeredPosition = centeredAccessibilityOrigin(for: actualSize, on: screen)
        guard let positionValue = AXValueCreate(.cgPoint, &centeredPosition),
              AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, positionValue as CFTypeRef) == .success else {
            throw ResizeError.unableToSetPosition
        }
    }

    private func matchingWindow(
        for target: WindowInfo,
        in snapshots: [AccessibilityWindowSnapshot]
    ) throws -> AccessibilityWindowSnapshot {
        let candidateWindows = AccessibilityWindowReader.userFacingWindows(from: snapshots)
        guard !candidateWindows.isEmpty else { throw ResizeError.windowNotFound }

        if target.hasDuplicateName {
            let geometryMatches = candidateWindows.filter {
                AccessibilityWindowReader.geometryMatches($0, bounds: target.bounds)
            }
            guard geometryMatches.count == 1, let match = geometryMatches.first else {
                throw ResizeError.ambiguousWindow
            }
            return match
        }

        if let nativeTitle = target.nativeTitle {
            let titleMatches = candidateWindows.filter { $0.title == nativeTitle }
            if titleMatches.count == 1, let match = titleMatches.first {
                return match
            }

            if titleMatches.isEmpty {
                let geometryMatches = candidateWindows.filter {
                    AccessibilityWindowReader.geometryMatches($0, bounds: target.bounds)
                }
                if geometryMatches.count == 1, let match = geometryMatches.first {
                    return match
                }
                if candidateWindows.count == 1, let match = candidateWindows.first {
                    return match
                }
                throw ResizeError.windowNotFound
            }

            let geometryMatches = titleMatches.filter {
                AccessibilityWindowReader.geometryMatches($0, bounds: target.bounds)
            }
            guard geometryMatches.count == 1, let match = geometryMatches.first else {
                throw ResizeError.ambiguousWindow
            }
            return match
        }

        if candidateWindows.count == 1, let match = candidateWindows.first {
            return match
        }

        let geometryMatches = candidateWindows.filter {
            AccessibilityWindowReader.geometryMatches($0, bounds: target.bounds)
        }
        guard geometryMatches.count == 1, let match = geometryMatches.first else {
            throw ResizeError.ambiguousWindow
        }
        return match
    }

    private func centeredAccessibilityOrigin(for size: CGSize, on screen: NSScreen) -> CGPoint {
        let visibleFrame = screen.visibleFrame
        let appKitX = visibleFrame.midX - size.width / 2
        let appKitY = visibleFrame.midY - size.height / 2

        // AppKit uses a bottom-left origin, while AX window positions use top-left.
        return CGPoint(
            x: appKitX,
            y: screen.frame.maxY - appKitY - size.height
        )
    }
}

struct SizePickerView: View {
    let windowName: String
    let onSelect: (WindowSize) -> String?
    let onCancel: () -> Void
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        VStack(spacing: 0) {
            Text(windowName)
                .font(.headline)
                .lineLimit(1)
                .padding(.top, 20)
                .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PresetSizeStore.shared.sizes) { size in
                        Button(size.label) {
                            errorMessage = onSelect(size)
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
