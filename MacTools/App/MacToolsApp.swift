import SwiftUI

@main
struct MacToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Window("MacTools", id: "main") {
            ContentView()
        }
        
        MenuBarExtra("MacTools", systemImage: "wrench.and.screwdriver") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
