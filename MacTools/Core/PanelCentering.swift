import AppKit

extension NSPanel {
    func centerOnVisibleScreen() {
        contentView?.layoutSubtreeIfNeeded()
        guard let screen = self.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            center()
            return
        }
        let screenFrame = screen.frame
        let panelSize = self.frame.size
        let origin = NSPoint(x: screenFrame.midX - panelSize.width / 2, y: screenFrame.midY - panelSize.height / 2)
        setFrameOrigin(origin)
    }
}
