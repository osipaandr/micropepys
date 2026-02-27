import XCTest
@testable import MicropepysCore

final class ChecklistManagerTests: XCTestCase {
    func testReadAllReturnsStoredItems() throws {
        let seeded = [
            ChecklistItem(title: "First"),
            ChecklistItem(title: "Second", isCompleted: true)
        ]
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: seeded)

        let manager = ChecklistManager(storage: storage)

        XCTAssertEqual(manager.readAll(), seeded)
    }

    func testAddAppendsItemAndPersists() throws {
        let storage = InMemoryChecklistStorage()
        let manager = ChecklistManager(storage: storage)

        let added = manager.add(title: "New task")

        XCTAssertEqual(manager.readAll().count, 1)
        XCTAssertEqual(manager.readAll().first?.title, "New task")
        XCTAssertEqual(manager.readAll().first?.id, added.id)
        XCTAssertFalse(manager.readAll().first?.isCompleted ?? true)

        let reloaded = ChecklistManager(storage: storage)
        XCTAssertEqual(reloaded.readAll().count, 1)
        XCTAssertEqual(reloaded.readAll().first?.title, "New task")
    }

    func testRemoveByIDDeletesMatchingItem() throws {
        let first = ChecklistItem(title: "Keep")
        let second = ChecklistItem(title: "Delete me")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second])
        let manager = ChecklistManager(storage: storage)

        manager.remove(id: second.id)

        XCTAssertEqual(manager.readAll(), [first])
    }

    func testRemoveByIDWithUnknownIDDoesNothing() throws {
        let first = ChecklistItem(title: "Keep")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first])
        let manager = ChecklistManager(storage: storage)

        manager.remove(id: UUID())

        XCTAssertEqual(manager.readAll(), [first])
    }

    func testRemoveAtOffsetsDeletesItemsAtOffsets() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second, third])
        let manager = ChecklistManager(storage: storage)

        manager.remove(at: IndexSet(integer: 1))

        XCTAssertEqual(manager.readAll(), [first, third])
    }

    func testToggleFlipsCompletionState() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.toggle(id: item.id)
        XCTAssertTrue(manager.readAll().first?.isCompleted ?? false)

        manager.toggle(id: item.id)
        XCTAssertFalse(manager.readAll().first?.isCompleted ?? true)
    }

    func testToggleWithUnknownIDDoesNothing() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.toggle(id: UUID())

        XCTAssertEqual(manager.readAll(), [item])
    }

    func testUpdateCanChangeTitleAndCompletion() throws {
        let item = ChecklistItem(title: "Old", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.update(id: item.id, title: "New", isCompleted: true)

        XCTAssertEqual(manager.readAll().first?.title, "New")
        XCTAssertTrue(manager.readAll().first?.isCompleted ?? false)
    }

    func testUpdateWithUnknownIDDoesNothing() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.update(id: UUID(), title: "Changed", isCompleted: true)

        XCTAssertEqual(manager.readAll(), [item])
    }

    func testClearCompletedRemovesOnlyCompletedItems() throws {
        let active = ChecklistItem(title: "Active", isCompleted: false)
        let done = ChecklistItem(title: "Done", isCompleted: true)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [active, done])
        let manager = ChecklistManager(storage: storage)

        manager.clearCompleted()

        XCTAssertEqual(manager.readAll(), [active])
    }

    func testMoveReordersItems() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second, third])
        let manager = ChecklistManager(storage: storage)

        manager.move(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(manager.readAll(), [second, third, first])
    }

    private func seedStorage(storage: InMemoryChecklistStorage, with items: [ChecklistItem]) {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(items)
        storage.set(data, forKey: "ChecklistItemsStorageKey")
    }
}

private final class InMemoryChecklistStorage: ChecklistStorage {
    private var raw: [String: Data] = [:]

    func data(forKey defaultName: String) -> Data? {
        raw[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        raw[defaultName] = value as? Data
    }
}
