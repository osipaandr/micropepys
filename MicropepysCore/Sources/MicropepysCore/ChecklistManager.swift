import Foundation
import Combine

public protocol ChecklistStorage {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: ChecklistStorage {}

public struct ChecklistItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

public final class ChecklistManager: ObservableObject {
    @Published public private(set) var items: [ChecklistItem] = []
    public private(set) var history: [[ChecklistItem]] = []
    private let storage: ChecklistStorage
    private let storageKey: String

    public init(
        storage: ChecklistStorage = UserDefaults.standard,
        storageKey: String = "ChecklistItemsStorageKey"
    ) {
        self.storage = storage
        self.storageKey = storageKey

        if let data = storage.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                let decodedItems = try decoder.decode([ChecklistItem].self, from: data)
                self.items = decodedItems
            } catch {
                // Keep default empty state when persisted payload is invalid.
            }
        }
        history = [items]
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(items)
            storage.set(data, forKey: storageKey)
        } catch {
            // Intentionally ignore persistence failures for now.
        }
    }

    private func recordCurrentState() {
        if history.last != items {
            history.append(items)
        }
    }

    public func readAll() -> [ChecklistItem] {
        items
    }

    public func add(title: String) {
        let item = ChecklistItem(title: title)
        items.append(item)
        recordCurrentState()
        persist()
    }

    public func remove(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            recordCurrentState()
            persist()
        }
    }

    public func remove(at offsets: IndexSet) {
        let validOffsets = offsets.filter { items.indices.contains($0) }
        guard !validOffsets.isEmpty else { return }

        for index in offsets.sorted(by: >) {
            guard items.indices.contains(index) else { continue }
            items.remove(at: index)
        }
        recordCurrentState()
        persist()
    }

    public func toggle(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()
        recordCurrentState()
        persist()
    }

    public func update(id: UUID, title: String? = nil, isCompleted: Bool? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let previous = items[index]
        var updated = previous
        if let title = title {
            updated.title = title
        }
        if let isCompleted = isCompleted {
            updated.isCompleted = isCompleted
        }
        guard updated != previous else { return }

        items[index] = updated
        recordCurrentState()
        persist()
    }

    public func clearCompleted() {
        guard items.contains(where: { $0.isCompleted }) else { return }

        items.removeAll(where: { $0.isCompleted })
        recordCurrentState()
        persist()
    }

    public func move(from source: IndexSet, to destination: Int) {
        let validSource = source.sorted().filter { items.indices.contains($0) }
        guard !validSource.isEmpty else { return }
        guard validSource.count > 1 || (validSource.first != destination && validSource.first != destination - 1) else { return }

        var movingItems: [ChecklistItem] = []
        for index in validSource.reversed() {
            movingItems.insert(items.remove(at: index), at: 0)
        }

        let clampedDestination = max(0, min(destination, items.count))
        items.insert(contentsOf: movingItems, at: clampedDestination)
        recordCurrentState()
        persist()
    }

    public func undo() {
        guard history.count > 1 else { return }
        history.removeLast()
        items = history.last ?? []
        persist()
    }

}
