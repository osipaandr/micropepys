import Foundation
import SwiftUI
internal import Combine

struct ChecklistItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

final class ChecklistManager: ObservableObject {
    @Published private(set) var items: [ChecklistItem] = []
    private let storageKey = "ChecklistItemsStorageKey"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                let decodedItems = try decoder.decode([ChecklistItem].self, from: data)
                self.items = decodedItems
            } catch {
                self.items = []
            }
        } else {
            self.items = []
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // silently fail or handle error as needed
        }
    }

    func readAll() -> [ChecklistItem] {
        items
    }

    @discardableResult
    func add(title: String) -> ChecklistItem {
        let item = ChecklistItem(title: title)
        items.append(item)
        persist()
        return item
    }

    func remove(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            persist()
        }
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persist()
    }

    func toggle(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()
        persist()
    }

    func update(id: UUID, title: String? = nil, isCompleted: Bool? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let title = title {
            items[index].title = title
        }
        if let isCompleted = isCompleted {
            items[index].isCompleted = isCompleted
        }
        persist()
    }

    func clearCompleted() {
        items.removeAll(where: { $0.isCompleted })
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persist()
    }
}
