protocol FeatureManager: AnyObject {
    func start()
    func stop()
}

extension FeatureManager {
    func restart() {
        stop()
        start()
    }
}
