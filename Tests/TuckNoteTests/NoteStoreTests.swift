import Foundation
import XCTest
@testable import TuckNote

actor StoreStorageSpy: NotebookStorage {
    var loaded: Result<Notebook, Error>
    private var saved: [Notebook] = []
    private var saveError: Error?

    init(loaded: Result<Notebook, Error> = .success(.blank()), saveError: Error? = nil) {
        self.loaded = loaded
        self.saveError = saveError
    }

    func load() async throws -> Notebook {
        try loaded.get()
    }

    func save(_ notebook: Notebook) async throws {
        if let saveError { throw saveError }
        saved.append(notebook)
    }

    func savedNotebooks() -> [Notebook] {
        saved
    }
}

private enum StoreStorageError: Error {
    case saveFailed
}

actor SuspendingStoreStorage: NotebookStorage {
    private var saves: [Notebook] = []
    private var activeSaveCount = 0
    private var maximumActiveSaveCount = 0
    private var saveStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var saveReleases: [CheckedContinuation<Void, Never>] = []

    func load() async throws -> Notebook {
        .blank()
    }

    func save(_ notebook: Notebook) async throws {
        saves.append(notebook)
        activeSaveCount += 1
        maximumActiveSaveCount = max(maximumActiveSaveCount, activeSaveCount)
        let waiters = saveStartedWaiters
        saveStartedWaiters.removeAll()
        waiters.forEach { $0.resume() }

        await withCheckedContinuation { saveReleases.append($0) }
        activeSaveCount -= 1
    }

    func waitUntilSaveCount(_ count: Int) async {
        while saves.count < count {
            await withCheckedContinuation { saveStartedWaiters.append($0) }
        }
    }

    func releaseNextSave() {
        guard !saveReleases.isEmpty else { return }
        saveReleases.removeFirst().resume()
    }

    func releaseAllSaves() {
        let releases = saveReleases
        saveReleases.removeAll()
        releases.forEach { $0.resume() }
    }

    func snapshot() -> (saves: [Notebook], active: Int, maximumActive: Int) {
        (saves, activeSaveCount, maximumActiveSaveCount)
    }
}

@MainActor
final class NoteStoreTests: XCTestCase {
    func testEditingUpdatesActivePageAndFlushPersists() async {
        let storage = StoreStorageSpy()
        let store = NoteStore(storage: storage, saveDelay: .seconds(60))

        await store.load()
        store.updateMarkdown("- [ ] Ship")
        await store.flush()

        XCTAssertEqual(store.notebook.pages[0].markdown, "- [ ] Ship")
        let saved = await storage.savedNotebooks()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].pages[0].markdown, "- [ ] Ship")
    }

    func testSelectionIsClampedToUTF16Length() async {
        let store = NoteStore(storage: StoreStorageSpy(), saveDelay: .seconds(60))
        await store.load()
        store.updateMarkdown("abc")

        store.updateSelection(location: 99, length: 4)

        XCTAssertEqual(store.activePage.selectionLocation, 3)
        XCTAssertEqual(store.activePage.selectionLength, 0)
    }

    func testFlushCancelsPendingDebounceAndPersistsCurrentStateOnce() async throws {
        let storage = StoreStorageSpy()
        let store = NoteStore(storage: storage, saveDelay: .milliseconds(20))
        await store.load()
        store.updateMarkdown("first")
        store.updateMarkdown("current")

        await store.flush()
        try await Task.sleep(for: .milliseconds(50))

        let saved = await storage.savedNotebooks()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].pages[0].markdown, "current")
    }

    func testFlushJoinsSuspendedDebouncedSaveWithoutStartingAnother() async {
        let storage = SuspendingStoreStorage()
        let store = NoteStore(storage: storage, saveDelay: .milliseconds(1))
        await store.load()
        store.updateMarkdown("current")
        await storage.waitUntilSaveCount(1)
        XCTAssertTrue(store.isSaving)

        let flushTask = Task { await store.flush() }
        for _ in 0..<100 {
            await Task.yield()
        }

        var snapshot = await storage.snapshot()
        XCTAssertEqual(snapshot.saves.count, 1)
        XCTAssertEqual(snapshot.active, 1)
        XCTAssertTrue(store.isSaving)

        await storage.releaseAllSaves()
        await flushTask.value

        snapshot = await storage.snapshot()
        XCTAssertEqual(snapshot.saves.count, 1)
        XCTAssertEqual(snapshot.active, 0)
        XCTAssertFalse(store.isSaving)
    }

    func testEditDuringSuspendedSavePersistsLatestStateWithoutConcurrentSave() async {
        let storage = SuspendingStoreStorage()
        let store = NoteStore(storage: storage, saveDelay: .milliseconds(1))
        await store.load()
        store.updateMarkdown("first")
        await storage.waitUntilSaveCount(1)

        store.updateMarkdown("latest")
        let flushTask = Task { await store.flush() }
        for _ in 0..<100 {
            await Task.yield()
        }

        var snapshot = await storage.snapshot()
        XCTAssertEqual(snapshot.saves.count, 1)
        await storage.releaseNextSave()
        await storage.waitUntilSaveCount(2)

        snapshot = await storage.snapshot()
        XCTAssertEqual(snapshot.maximumActive, 1)
        XCTAssertEqual(snapshot.saves[1].pages[0].markdown, "latest")
        await storage.releaseNextSave()
        await flushTask.value
        XCTAssertFalse(store.isSaving)
    }

    func testPageActionsAddSelectAndRemovePages() async {
        let store = NoteStore(storage: StoreStorageSpy(), saveDelay: .seconds(60))
        await store.load()
        let originalID = store.activePage.id

        store.addPage()
        let addedID = store.activePage.id
        XCTAssertNotEqual(addedID, originalID)
        XCTAssertEqual(store.notebook.pages.count, 2)

        store.selectPage(originalID)
        XCTAssertEqual(store.activePage.id, originalID)

        store.removeActivePage()
        XCTAssertEqual(store.notebook.pages.count, 1)
        XCTAssertEqual(store.activePage.id, addedID)
    }

    func testAddingBeyondFivePagesShowsLimitNotice() async {
        let store = NoteStore(storage: StoreStorageSpy(), saveDelay: .seconds(60))
        await store.load()

        for _ in 1..<Notebook.maximumPageCount {
            store.addPage()
        }
        store.addPage()

        XCTAssertEqual(store.notebook.pages.count, Notebook.maximumPageCount)
        XCTAssertNotNil(store.notice)
    }

    func testCorruptLoadUsesBlankNotebookAndShowsNotice() async {
        let recoveredURL = URL(fileURLWithPath: "/tmp/notebook-corrupt.json")
        let storage = StoreStorageSpy(loaded: .failure(StorageError.corruptNotebookRecovered(recoveredURL)))
        let store = NoteStore(storage: storage, saveDelay: .seconds(60))

        await store.load()

        XCTAssertEqual(store.notebook.pages.count, 1)
        XCTAssertEqual(store.notebook.pages[0].markdown, "")
        XCTAssertNotNil(store.notice)
    }

    func testSaveFailureShowsNoticeAndClearsSavingState() async {
        let storage = StoreStorageSpy(saveError: StoreStorageError.saveFailed)
        let store = NoteStore(storage: storage, saveDelay: .seconds(60))
        await store.load()
        store.updateMarkdown("unsaved")

        await store.flush()

        XCTAssertNotNil(store.notice)
        XCTAssertFalse(store.isSaving)
    }
}
