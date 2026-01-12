import SwiftUI

@main
struct MacToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Window("MacTools", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
