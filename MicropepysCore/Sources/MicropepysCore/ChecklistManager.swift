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

    public func readAll() -> [ChecklistItem] {
        items
    }

    public func add(title: String) {
        let item = ChecklistItem(title: title)
        items.append(item)
        persist()
    }

    public func remove(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            persist()
        }
    }

    public func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard items.indices.contains(index) else { continue }
            items.remove(at: index)
        }
        persist()
    }

    public func toggle(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()
        persist()
    }

    public func update(id: UUID, title: String? = nil, isCompleted: Bool? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let title = title {
            items[index].title = title
        }
        if let isCompleted = isCompleted {
            items[index].isCompleted = isCompleted
        }
        persist()
    }

    public func clearCompleted() {
        items.removeAll(where: { $0.isCompleted })
        persist()
    }

    public func move(from source: IndexSet, to destination: Int) {
        let validSource = source.sorted().filter { items.indices.contains($0) }
        guard !validSource.isEmpty else { return }

        var movingItems: [ChecklistItem] = []
        for index in validSource.reversed() {
            movingItems.insert(items.remove(at: index), at: 0)
        }

        let clampedDestination = max(0, min(destination, items.count))
        items.insert(contentsOf: movingItems, at: clampedDestination)
        persist()
    }

}
