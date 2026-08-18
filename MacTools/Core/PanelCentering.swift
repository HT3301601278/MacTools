import AppKit

extension NSWindow {
    func centerOnVisibleScreen() {
        contentView?.layoutSubtreeIfNeeded()
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            center()
            return
        }
        let panelSize = frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2
        )
        setFrameOrigin(origin)
    }
}
