import XCTest
@testable import Micropepys

final class ChecklistManagerTests: XCTestCase {
    private let storageKey = "ChecklistItemsStorageKey"

    override func setUpWithError() throws {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func testReadAllReturnsStoredItems() throws {
        let seeded = [
            ChecklistItem(title: "First"),
            ChecklistItem(title: "Second", isCompleted: true)
        ]
        seedStorage(with: seeded)

        let manager = ChecklistManager()

        XCTAssertEqual(manager.readAll(), seeded)
    }

    func testAddAppendsItemAndPersists() throws {
        let manager = ChecklistManager()

        let added = manager.add(title: "New task")

        XCTAssertEqual(manager.readAll().count, 1)
        XCTAssertEqual(manager.readAll().first?.title, "New task")
        XCTAssertEqual(manager.readAll().first?.id, added.id)
        XCTAssertFalse(manager.readAll().first?.isCompleted ?? true)

        let reloaded = ChecklistManager()
        XCTAssertEqual(reloaded.readAll().count, 1)
        XCTAssertEqual(reloaded.readAll().first?.title, "New task")
    }

    func testRemoveByIDDeletesMatchingItem() throws {
        let first = ChecklistItem(title: "Keep")
        let second = ChecklistItem(title: "Delete me")
        seedStorage(with: [first, second])
        let manager = ChecklistManager()

        manager.remove(id: second.id)

        XCTAssertEqual(manager.readAll(), [first])
    }

    func testRemoveByIDWithUnknownIDDoesNothing() throws {
        let first = ChecklistItem(title: "Keep")
        seedStorage(with: [first])
        let manager = ChecklistManager()

        manager.remove(id: UUID())

        XCTAssertEqual(manager.readAll(), [first])
    }

    func testRemoveAtOffsetsDeletesItemsAtOffsets() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        seedStorage(with: [first, second, third])
        let manager = ChecklistManager()

        manager.remove(at: IndexSet(integer: 1))

        XCTAssertEqual(manager.readAll(), [first, third])
    }

    func testToggleFlipsCompletionState() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        seedStorage(with: [item])
        let manager = ChecklistManager()

        manager.toggle(id: item.id)
        XCTAssertTrue(manager.readAll().first?.isCompleted ?? false)

        manager.toggle(id: item.id)
        XCTAssertFalse(manager.readAll().first?.isCompleted ?? true)
    }

    func testToggleWithUnknownIDDoesNothing() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        seedStorage(with: [item])
        let manager = ChecklistManager()

        manager.toggle(id: UUID())

        XCTAssertEqual(manager.readAll(), [item])
    }

    func testUpdateCanChangeTitleAndCompletion() throws {
        let item = ChecklistItem(title: "Old", isCompleted: false)
        seedStorage(with: [item])
        let manager = ChecklistManager()

        manager.update(id: item.id, title: "New", isCompleted: true)

        XCTAssertEqual(manager.readAll().first?.title, "New")
        XCTAssertTrue(manager.readAll().first?.isCompleted ?? false)
    }

    func testUpdateWithUnknownIDDoesNothing() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        seedStorage(with: [item])
        let manager = ChecklistManager()

        manager.update(id: UUID(), title: "Changed", isCompleted: true)

        XCTAssertEqual(manager.readAll(), [item])
    }

    func testClearCompletedRemovesOnlyCompletedItems() throws {
        let active = ChecklistItem(title: "Active", isCompleted: false)
        let done = ChecklistItem(title: "Done", isCompleted: true)
        seedStorage(with: [active, done])
        let manager = ChecklistManager()

        manager.clearCompleted()

        XCTAssertEqual(manager.readAll(), [active])
    }

    func testMoveReordersItems() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        seedStorage(with: [first, second, third])
        let manager = ChecklistManager()

        manager.move(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(manager.readAll(), [second, third, first])
    }

    private func seedStorage(with items: [ChecklistItem]) {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(items)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

}
