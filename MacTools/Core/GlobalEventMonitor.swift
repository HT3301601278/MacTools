import AppKit

final class GlobalEventMonitor {

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        if monitor != nil {
            return true
        }
        guard let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) else {
            return false
        }
        self.monitor = monitor
        return true
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
