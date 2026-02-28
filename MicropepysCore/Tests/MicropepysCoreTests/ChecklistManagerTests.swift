import XCTest
@testable import MicropepysCore

final class ChecklistManagerTests: XCTestCase {
    // MARK: - readAll()

    func testReadAllReturnsStoredItems() throws {
        let expected = [
            ChecklistItem(title: "First"),
            ChecklistItem(title: "Second", isCompleted: true)
        ]
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: expected)

        let manager = ChecklistManager(storage: storage)
        let result = manager.readAll()

        XCTAssertEqual(result, expected)
        XCTAssertEqual(manager.history, [expected])
    }

    // MARK: - add(title:)

    func testAddAppendsItemAndPersists() throws {
        let storage = InMemoryChecklistStorage()
        let manager = ChecklistManager(storage: storage)

        manager.add(title: "New task")
        let current = manager.readAll()
        let reloaded = ChecklistManager(storage: storage)
        let persisted = reloaded.readAll()

        XCTAssertEqual(current, persisted)
        XCTAssertEqual(manager.history, [[], current])
    }

    // MARK: - remove(id:)

    func testRemoveByIDDeletesMatchingItem() throws {
        let first = ChecklistItem(title: "Keep")
        let second = ChecklistItem(title: "Delete me")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second])
        let manager = ChecklistManager(storage: storage)

        manager.remove(id: second.id)
        let result = manager.readAll()

        XCTAssertEqual(result, [first])
        XCTAssertEqual(manager.history, [[first, second], [first]])
    }

    func testRemoveByIDWithUnknownIDDoesNothing() throws {
        let first = ChecklistItem(title: "Keep")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first])
        let manager = ChecklistManager(storage: storage)

        manager.remove(id: UUID())
        let result = manager.readAll()

        XCTAssertEqual(result, [first])
        XCTAssertEqual(manager.history, [[first]])
    }

    // MARK: - remove(at:)

    func testRemoveAtOffsetsDeletesItemsAtOffsets() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second, third])
        let manager = ChecklistManager(storage: storage)

        manager.remove(at: IndexSet(integer: 1))
        let result = manager.readAll()

        XCTAssertEqual(result, [first, third])
        XCTAssertEqual(manager.history, [[first, second, third], [first, third]])
    }

    // MARK: - toggle(id:)

    func testToggleFlipsCompletionState() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.toggle(id: item.id)
        manager.toggle(id: item.id)
        let result = manager.readAll()

        XCTAssertEqual(result, [item])
        XCTAssertEqual(
            manager.history,
            [
                [item],
                [ChecklistItem(id: item.id, title: item.title, isCompleted: true, createdAt: item.createdAt)],
                [item]
            ]
        )
    }

    func testToggleWithUnknownIDDoesNothing() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.toggle(id: UUID())
        let result = manager.readAll()

        XCTAssertEqual(result, [item])
        XCTAssertEqual(manager.history, [[item]])
    }

    // MARK: - update(id:title:isCompleted:)

    func testUpdateCanChangeTitleAndCompletion() throws {
        let item = ChecklistItem(title: "Old", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.update(id: item.id, title: "New", isCompleted: true)
        let result = manager.readAll()
        let updated = [ChecklistItem(id: item.id, title: "New", isCompleted: true, createdAt: item.createdAt)]

        XCTAssertEqual(result, updated)
        XCTAssertEqual(manager.history, [[item], updated])
    }

    func testUpdateWithUnknownIDDoesNothing() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.update(id: UUID(), title: "Changed", isCompleted: true)
        let result = manager.readAll()

        XCTAssertEqual(result, [item])
        XCTAssertEqual(manager.history, [[item]])
    }

    // MARK: - clearCompleted()

    func testClearCompletedRemovesOnlyCompletedItems() throws {
        let active = ChecklistItem(title: "Active", isCompleted: false)
        let done = ChecklistItem(title: "Done", isCompleted: true)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [active, done])
        let manager = ChecklistManager(storage: storage)

        manager.clearCompleted()
        let result = manager.readAll()

        XCTAssertEqual(result, [active])
        XCTAssertEqual(manager.history, [[active, done], [active]])
    }

    // MARK: - move(from:to:)

    func testMoveReordersItems() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second, third])
        let manager = ChecklistManager(storage: storage)

        manager.move(from: IndexSet(integer: 0), to: 3)
        let result = manager.readAll()

        XCTAssertEqual(result, [second, third, first])
        XCTAssertEqual(manager.history, [[first, second, third], [second, third, first]])
    }

    // MARK: - undo()

    func testUndoWithNoHistoryDoesNothing() throws {
        let storage = InMemoryChecklistStorage()
        let manager = ChecklistManager(storage: storage)

        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [])
        XCTAssertEqual(manager.history, [[]])
    }

    func testUndoRevertsAddMutation() throws {
        let storage = InMemoryChecklistStorage()
        let manager = ChecklistManager(storage: storage)
        manager.add(title: "Task")

        let expected: [ChecklistItem] = []
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, expected)
        XCTAssertEqual(manager.history, [expected])
    }

    func testUndoRevertsToggleMutation() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.toggle(id: item.id)
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [item])
        XCTAssertEqual(manager.history, [[item]])
    }

    func testUndoRevertsUpdateMutation() throws {
        let item = ChecklistItem(title: "Old", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.update(id: item.id, title: "New", isCompleted: true)
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [item])
        XCTAssertEqual(manager.history, [[item]])
    }

    func testUndoRevertsRemoveByIDMutation() throws {
        let first = ChecklistItem(title: "Keep")
        let second = ChecklistItem(title: "Delete")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second])
        let manager = ChecklistManager(storage: storage)

        manager.remove(id: second.id)
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [first, second])
        XCTAssertEqual(manager.history, [[first, second]])
    }

    func testUndoRevertsRemoveAtMutation() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second, third])
        let manager = ChecklistManager(storage: storage)

        manager.remove(at: IndexSet(integer: 1))
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [first, second, third])
        XCTAssertEqual(manager.history, [[first, second, third]])
    }

    func testUndoRevertsClearCompletedMutation() throws {
        let active = ChecklistItem(title: "Active", isCompleted: false)
        let done = ChecklistItem(title: "Done", isCompleted: true)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [active, done])
        let manager = ChecklistManager(storage: storage)

        manager.clearCompleted()
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [active, done])
        XCTAssertEqual(manager.history, [[active, done]])
    }

    func testUndoRevertsMoveMutation() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second, third])
        let manager = ChecklistManager(storage: storage)

        manager.move(from: IndexSet(integer: 0), to: 3)
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [first, second, third])
        XCTAssertEqual(manager.history, [[first, second, third]])
    }

    func testUndoAfterNoOpMutationDoesNothing() throws {
        let item = ChecklistItem(title: "Task", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [item])
        let manager = ChecklistManager(storage: storage)

        manager.remove(id: UUID())
        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, [item])
        XCTAssertEqual(manager.history, [[item]])
    }

    // MARK: - apply(operations:)

    func testApplyOperationsRunsBatchInOrder() throws {
        let first = ChecklistItem(title: "Passport", isCompleted: false)
        let second = ChecklistItem(title: "Presentation", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second])
        let manager = ChecklistManager(storage: storage)

        manager.apply(operations: [
            .complete(id: first.id),
            .add(title: "Start the laundry"),
            .edit(id: second.id, title: "Prepare Friday presentation", isCompleted: nil)
        ])
        let result = manager.readAll()
        let added = result[2]

        XCTAssertEqual(result, [
            ChecklistItem(id: first.id, title: first.title, isCompleted: true, createdAt: first.createdAt),
            ChecklistItem(id: second.id, title: "Prepare Friday presentation", isCompleted: false, createdAt: second.createdAt),
            ChecklistItem(id: added.id, title: "Start the laundry", isCompleted: false, createdAt: added.createdAt)
        ])
        XCTAssertEqual(manager.history, [[first, second], result])
    }

    func testUndoAfterApplyRevertsWholeBatch() throws {
        let first = ChecklistItem(title: "Passport", isCompleted: false)
        let second = ChecklistItem(title: "Presentation", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second])
        let manager = ChecklistManager(storage: storage)

        let expectedBefore = [first, second]
        manager.apply(operations: [
            .complete(id: first.id),
            .edit(id: second.id, title: "Prepare Friday presentation", isCompleted: nil)
        ])

        manager.undo()
        let result = manager.readAll()

        XCTAssertEqual(result, expectedBefore)
        XCTAssertEqual(manager.history, [expectedBefore])
    }

    func testApplyWithEmptyOperationsIsNoOpAndDoesNotChangeHistory() throws {
        let first = ChecklistItem(title: "Passport", isCompleted: false)
        let second = ChecklistItem(title: "Presentation", isCompleted: false)
        let beforeNoOp = [first, second]

        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: beforeNoOp)

        let manager = ChecklistManager(storage: storage)
        let historyBeforeNoOp = manager.history

        manager.apply(operations: [])
        let afterNoOp = manager.readAll()
        let historyAfterNoOp = manager.history

        XCTAssertEqual(afterNoOp, beforeNoOp)
        XCTAssertEqual(historyAfterNoOp, historyBeforeNoOp)
    }

    func testApplySupportsRemoveOperation() throws {
        let first = ChecklistItem(title: "Passport", isCompleted: false)
        let second = ChecklistItem(title: "Presentation", isCompleted: false)
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second])
        let manager = ChecklistManager(storage: storage)

        manager.apply(operations: [
            .remove(id: second.id),
            .add(title: "Laundry"),
            .edit(id: first.id, title: "Passport sent", isCompleted: true)
        ])
        let result = manager.readAll()
        let added = result[1]

        XCTAssertEqual(result, [
            ChecklistItem(id: first.id, title: "Passport sent", isCompleted: true, createdAt: first.createdAt),
            ChecklistItem(id: added.id, title: "Laundry", isCompleted: false, createdAt: added.createdAt)
        ])
        XCTAssertEqual(manager.history, [[first, second], result])
    }

    func testApplySupportsMoveOperation() throws {
        let first = ChecklistItem(title: "First")
        let second = ChecklistItem(title: "Second")
        let third = ChecklistItem(title: "Third")
        let storage = InMemoryChecklistStorage()
        seedStorage(storage: storage, with: [first, second, third])
        let manager = ChecklistManager(storage: storage)

        manager.apply(operations: [
            .move(source: IndexSet(integer: 0), destination: 3),
            .remove(id: second.id),
            .add(title: "Fourth")
        ])
        let result = manager.readAll()
        let added = result[2]

        XCTAssertEqual(result, [
            third,
            first,
            ChecklistItem(id: added.id, title: "Fourth", isCompleted: false, createdAt: added.createdAt)
        ])
        XCTAssertEqual(manager.history, [[first, second, third], result])
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
