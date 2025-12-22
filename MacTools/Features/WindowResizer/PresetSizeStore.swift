import SwiftUI

@Observable
final class PresetSizeStore {
    static let shared = PresetSizeStore()
    
    private let key = "presetWindowSizes"
    
    var sizes: [WindowSize] {
        didSet { save() }
    }
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([WindowSize].self, from: data) {
            sizes = decoded
        } else {
            sizes = Self.defaultSizes
        }
    }
    
    func add(width: Int, height: Int) {
        sizes.append(WindowSize(width: width, height: height))
    }
    
    func delete(at offsets: IndexSet) {
        sizes.remove(atOffsets: offsets)
    }
    
    func move(from source: IndexSet, to destination: Int) {
        sizes.move(fromOffsets: source, toOffset: destination)
    }
    
    func update(id: UUID, width: Int, height: Int) {
        if let idx = sizes.firstIndex(where: { $0.id == id }) {
            sizes[idx] = WindowSize(id: id, width: width, height: height)
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(sizes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func resetToDefault() {
        sizes = Self.defaultSizes
    }
    
    private static let defaultSizes: [WindowSize] = [
        WindowSize(width: 640, height: 360),
        WindowSize(width: 800, height: 500),
        WindowSize(width: 960, height: 540),
        WindowSize(width: 1024, height: 640),
        WindowSize(width: 1280, height: 720),
        WindowSize(width: 1280, height: 800),
        WindowSize(width: 1360, height: 765),
        WindowSize(width: 1440, height: 900),
        WindowSize(width: 1600, height: 900),
        WindowSize(width: 1600, height: 1000),
    ]
}
