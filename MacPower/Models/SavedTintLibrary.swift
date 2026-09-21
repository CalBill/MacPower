import Foundation

struct SavedTintPreset<Payload: Codable & Equatable>: Codable, Equatable, Identifiable, Sendable
where Payload: Sendable {
    var id: UUID
    var name: String
    var payload: Payload

    init(id: UUID = UUID(), name: String, payload: Payload) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.payload = payload
    }
}

struct SavedTintLibrary: Codable, Equatable, Sendable {
    var menuBar: [SavedTintPreset<MenuBarTintScheme>]
    var ring: [SavedTintPreset<RingTintSettings>]
    var flow: [SavedTintPreset<FlowTintSettings>]

    static let empty = SavedTintLibrary(menuBar: [], ring: [], flow: [])
    static let maxCount = 20

    func addingMenuBar(name: String, scheme: MenuBarTintScheme) -> SavedTintLibrary {
        var copy = self
        var payload = scheme
        if payload.preset != .off { payload.preset = .custom }
        copy.menuBar = capped(copy.menuBar + [SavedTintPreset(name: name, payload: payload)])
        return copy
    }

    func addingRing(name: String, settings: RingTintSettings) -> SavedTintLibrary {
        var copy = self
        let payload = settings.markedCustom()
        copy.ring = capped(copy.ring + [SavedTintPreset(name: name, payload: payload)])
        return copy
    }

    func addingFlow(name: String, settings: FlowTintSettings) -> SavedTintLibrary {
        var copy = self
        let payload = settings.markedCustom()
        copy.flow = capped(copy.flow + [SavedTintPreset(name: name, payload: payload)])
        return copy
    }

    func removingMenuBar(id: UUID) -> SavedTintLibrary {
        var copy = self
        copy.menuBar.removeAll { $0.id == id }
        return copy
    }

    func removingRing(id: UUID) -> SavedTintLibrary {
        var copy = self
        copy.ring.removeAll { $0.id == id }
        return copy
    }

    func removingFlow(id: UUID) -> SavedTintLibrary {
        var copy = self
        copy.flow.removeAll { $0.id == id }
        return copy
    }

    private func capped<T>(_ items: [SavedTintPreset<T>]) -> [SavedTintPreset<T>] {
        Array(items.suffix(Self.maxCount))
    }
}

enum MenuBarPresetPickerItem: Hashable, Identifiable {
    case builtin(MenuBarTintPreset)
    case saved(UUID)

    var id: String {
        switch self {
        case .builtin(let preset): "builtin-\(preset.rawValue)"
        case .saved(let id): "saved-\(id.uuidString)"
        }
    }
}

enum PopoverPresetPickerItem: Hashable, Identifiable {
    case builtin(PopoverTintPreset)
    case saved(UUID)

    var id: String {
        switch self {
        case .builtin(let preset): "builtin-\(preset.rawValue)"
        case .saved(let id): "saved-\(id.uuidString)"
        }
    }
}
