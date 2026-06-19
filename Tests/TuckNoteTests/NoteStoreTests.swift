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
