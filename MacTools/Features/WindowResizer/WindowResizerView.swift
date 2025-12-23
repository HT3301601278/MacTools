import SwiftUI

struct WindowResizerView: View {
    @AppStorage("windowResizerEnabled") private var windowResizerEnabled = true
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var isRecordingShortcut = false
    @State private var shortcutDisplay = WindowResizerManager.shared.shortcutDescription
    @State private var showAddSheet = false
    @State private var editingSize: WindowSize?
    @State private var shortcutMonitor: Any?
    
    var body: some View {
        Form {
            Section {
                Toggle("启用窗口调整功能", isOn: $windowResizerEnabled)
                    .disabled(!hasAccessibility)
                    .onChange(of: windowResizerEnabled) { _, enabled in
                        if enabled {
                            WindowResizerManager.shared.start()
                        } else {
                            WindowResizerManager.shared.stop()
                        }
                    }
            } footer: {
                Text("按下快捷键后会弹出窗口选择器，选择窗口后再选择目标尺寸")
                    .foregroundStyle(.secondary)
            }
            
            Section("快捷键") {
                HStack {
                    Text("触发快捷键")
                    Spacer()
                    
                    if isRecordingShortcut {
                        Text("按下新快捷键...")
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                    } else {
                        Button(shortcutDisplay) {
                            startRecording()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Section {
                List {
                    ForEach(PresetSizeStore.shared.sizes) { size in
                        SizeRowView(size: size) {
                            editingSize = size
                        } onDelete: {
                            if let idx = PresetSizeStore.shared.sizes.firstIndex(where: { $0.id == size.id }) {
                                PresetSizeStore.shared.delete(at: IndexSet(integer: idx))
                            }
                        }
                    }
                    .onMove { PresetSizeStore.shared.move(from: $0, to: $1) }
                    .onDelete { PresetSizeStore.shared.delete(at: $0) }
                }
                .listStyle(.plain)
                .frame(minHeight: 200)
            } header: {
                HStack {
                    Text("预设尺寸")
                    Spacer()
                    Button {
                        PresetSizeStore.shared.resetToDefault()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundStyle(.orange)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .help("恢复默认")
                    
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .help("新增尺寸")
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddSheet) {
            SizeEditSheet(mode: .add)
        }
        .sheet(item: $editingSize) { size in
            SizeEditSheet(mode: .edit(size))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
            shortcutDisplay = WindowResizerManager.shared.shortcutDescription
        }
    }
    
    private func startRecording() {
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
        }
        
        isRecordingShortcut = true
        
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            let hasModifier = event.modifierFlags.contains(.command) ||
                              event.modifierFlags.contains(.control) ||
                              event.modifierFlags.contains(.option)
            
            if hasModifier {
                WindowResizerManager.shared.keyCode = event.keyCode
                WindowResizerManager.shared.modifiers = modifiers
                WindowResizerManager.shared.restart()
                
                shortcutDisplay = WindowResizerManager.shared.shortcutDescription
                isRecordingShortcut = false
                if let monitor = shortcutMonitor {
                    NSEvent.removeMonitor(monitor)
                    shortcutMonitor = nil
                }
                return nil
            }
            
            if event.keyCode == 53 { // Escape
                isRecordingShortcut = false
                if let monitor = shortcutMonitor {
                    NSEvent.removeMonitor(monitor)
                    shortcutMonitor = nil
                }
                return nil
            }
            
            return event
        }
    }
}

struct SizeRowView: View {
    let size: WindowSize
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
            
            Text(size.label)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            
            Spacer()
            
            if isHovering {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

enum SizeEditMode: Identifiable {
    case add
    case edit(WindowSize)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let size): return size.id.uuidString
        }
    }
}

struct SizeEditSheet: View {
    let mode: SizeEditMode
    @Environment(\.dismiss) private var dismiss
    
    @State private var width = ""
    @State private var height = ""
    
    private var title: String {
        switch mode {
        case .add: return "新增尺寸"
        case .edit: return "编辑尺寸"
        }
    }
    
    private var isValid: Bool {
        guard let w = Int(width), let h = Int(height) else { return false }
        return w > 0 && h > 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("宽度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("1920", text: $width)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                Text("×")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 18)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("高度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("1080", text: $height)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }
            
            HStack(spacing: 12) {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("确定") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(minWidth: 280)
        .onAppear {
            if case .edit(let size) = mode {
                width = String(size.width)
                height = String(size.height)
            }
        }
    }
    
    private func save() {
        guard let w = Int(width), let h = Int(height) else { return }
        switch mode {
        case .add:
            PresetSizeStore.shared.add(width: w, height: h)
        case .edit(let size):
            PresetSizeStore.shared.update(id: size.id, width: w, height: h)
        }
        dismiss()
    }
}
