import AppKit

extension NSPanel {
    func centerOnVisibleScreen() {
        contentView?.layoutSubtreeIfNeeded()
        guard let screen = self.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            center()
            return
        }
        let frame = screen.visibleFrame
        let size = self.frame.size
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        setFrameOrigin(origin)
    }
}
