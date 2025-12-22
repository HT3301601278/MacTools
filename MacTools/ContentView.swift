import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case general = "通用"
    case dockToggle = "Dock"
    case windowResizer = "窗口"
    case windowPin = "置顶"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .dockToggle: return "dock.rectangle"
        case .windowResizer: return "macwindow"
        case .windowPin: return "pin"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem = .general

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 120, ideal: 140)
        } detail: {
            switch selection {
            case .general:
                GeneralSettingsView()
            case .dockToggle:
                DockToggleView()
            case .windowResizer:
                WindowResizerView()
            case .windowPin:
                WindowPinView()
            }
        }
        .frame(minWidth: 500, minHeight: 350)
    }
}
