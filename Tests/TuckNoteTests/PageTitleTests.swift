import Foundation
import XCTest
@testable import TuckNote

final class PageTitleTests: XCTestCase {
    @MainActor
    func testRemovingContextMenuTargetPersistsWithoutSwitchingCurrentPage() async throws {
        let storage = StoreStorageSpy()
        let store = NoteStore(storage: storage, saveDelay: .seconds(60))
        await store.load()
        let target = store.activePage.id
        store.addPage()
        store.updateMarkdown("Keep writing")
        store.updateSelection(location: 4, length: 2)
        let current = store.activePage
        store.removePage(target)
        XCTAssertEqual(store.notebook.pages, [current])
        XCTAssertEqual(store.activePage.id, current.id)
        store.removePage(UUID())
        XCTAssertEqual(store.notebook.pages, [current])
        await store.flush()
        let saved = await storage.savedNotebooks()
        XCTAssertEqual(saved.last, store.notebook)
        store.removePage(current.id)
        XCTAssertEqual(store.activePage.id, current.id)
        XCTAssertEqual(store.activePage.markdown, "")
        await store.flush()
    }

    func testDeletingInactivePagePreservesCurrentNoteAndSelection() {
        var notebook = Notebook.blank()
        notebook.addPage()
        notebook.addPage()
        notebook.pages[2].markdown = "Still writing here"
        notebook.pages[2].selectionLocation = 5
        let current = notebook.pages[2]
        notebook.removePage(id: notebook.pages[0].id)
        XCTAssertEqual(notebook.activePageID, current.id)
        XCTAssertEqual(notebook.pages.last, current)
    }

    func testEveryAddedPageUsesCompactTabEvenWhenASuggestedNameIsAvailable() throws {
        var notebook = Notebook.blank()
        notebook.addPage()
        let pages = try encodedPages(notebook)
        XCTAssertEqual(pages[0]["isCompactTab"] as? Bool, false)
        XCTAssertEqual(pages[1]["isCompactTab"] as? Bool, true)
    }

    @MainActor
    func testLegacyTabMigrationKeepsOnlyFirstThreeNamed() async throws {
        let pages = (0..<7).map { NotePage(title: Notebook.defaultTitle(at: $0)) }
        let store = NoteStore(storage: StoreStorageSpy(loaded: .success(Notebook(schemaVersion: 1, pages: pages, activePageID: pages[0].id))))
        await store.load()
        var encoded = try encodedPages(store.notebook)
        XCTAssertEqual(encoded.compactMap { $0["isCompactTab"] as? Bool }, [false, false, false, true, true, true, true])
        store.removeActivePage()
        encoded = try encodedPages(store.notebook)
        XCTAssertEqual(encoded[2]["isCompactTab"] as? Bool, true)
        XCTAssertEqual(store.notebook.pages[2].title, "Note 4")
        let reopened = try JSONDecoder().decode(Notebook.self, from: JSONEncoder().encode(store.notebook))
        XCTAssertEqual(reopened.pages.map(\.isCompactTab), [false, false, true, true, true, true])
        let compactID = store.notebook.pages[2].id
        XCTAssertTrue(store.renamePage(compactID, to: "Renamed extra page"))
        XCTAssertEqual(store.notebook.pages[2].isCompactTab, true)
        await store.flush()
    }
    @MainActor
    func testRenamePersistsAndDoesNotTouchContentOrActivePage() async throws {
        let storage = StoreStorageSpy()
        let store = NoteStore(storage: storage, saveDelay: .seconds(60))
        await store.load()
        let first = store.activePage.id
        store.updateMarkdown("Keep this note")
        store.updateSelection(location: 4, length: 2)
        store.addPage()
        let active = store.activePage.id
        XCTAssertTrue(store.renamePage(first, to: "  \u{7814}\u{7A76}\n Ideas  "))
        XCTAssertEqual(store.notebook.pages[0].title, "\u{7814}\u{7A76} Ideas")
        XCTAssertEqual(store.notebook.pages[0].markdown, "Keep this note")
        XCTAssertEqual(store.notebook.pages[0].selectionLocation, 4)
        XCTAssertEqual(store.notebook.pages[0].selectionLength, 2)
        XCTAssertEqual(store.activePage.id, active)
        await store.flush()
        let snapshots = await storage.savedNotebooks()
        XCTAssertEqual(snapshots.last?.pages[0].title, "\u{7814}\u{7A76} Ideas")
        let reopened = NoteStore(storage: StoreStorageSpy(loaded: .success(try XCTUnwrap(snapshots.last))))
        await reopened.load()
        XCTAssertEqual(reopened.notebook.pages[0].title, "\u{7814}\u{7A76} Ideas")
    }

    @MainActor
    func testRenameRejectsBlankAndDeletedPagesAndBoundsLongNames() async {
        let store = NoteStore(storage: StoreStorageSpy(), saveDelay: .seconds(60))
        await store.load()
        let id = store.activePage.id
        XCTAssertFalse(store.renamePage(id, to: " \n\t "))
        XCTAssertEqual(store.activePage.title, "Today")
        XCTAssertFalse(store.renamePage(UUID(), to: "Deleted"))
        XCTAssertTrue(store.renamePage(id, to: String(repeating: "\u{7B14}\u{8BB0}", count: 50)))
        XCTAssertEqual(store.activePage.title?.count, 40)
        store.removeActivePage()
        XCTAssertEqual(store.activePage.title?.count, 40)
    }

    func testNewPagesGetUsefulDefaultTitles() throws {
        var notebook = Notebook.blank()
        notebook.addPage()
        notebook.addPage()
        notebook.addPage()
        let pages = try encodedPages(notebook)
        XCTAssertEqual(pages.compactMap { $0["title"] as? String }, ["Today", "Ideas", "Little things", "Note 4"])
    }

    func testDeletingAnotherPageDoesNotRenameRemainingPages() {
        var notebook = Notebook.blank()
        notebook.addPage()
        notebook.addPage()
        let remainingID = notebook.pages[2].id
        notebook.removePage(id: notebook.pages[0].id)
        XCTAssertEqual(notebook.pages.last?.id, remainingID)
        XCTAssertEqual(notebook.pages.last?.title, "Little things")
    }

    @MainActor
    func testLoadingNamedNotebookDoesNotResaveOrReplaceTitles() async {
        let page = NotePage(markdown: "# Do not change", title: "My own name", isCompactTab: false)
        let notebook = Notebook(schemaVersion: 1, pages: [page], activePageID: page.id)
        let storage = StoreStorageSpy(loaded: .success(notebook))
        let store = NoteStore(storage: storage)
        await store.load()
        await store.flush()
        XCTAssertEqual(store.notebook, notebook)
        let saves = await storage.savedNotebooks()
        XCTAssertTrue(saves.isEmpty)
    }

    func testPageTitleSurvivesRoundTripWithUnicode() throws {
        let page = NotePage(markdown: "keep this text", selectionLocation: 3, selectionLength: 2)
        let notebook = Notebook(schemaVersion: 1, pages: [page], activePageID: page.id)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(notebook)) as? [String: Any])
        var pages = try XCTUnwrap(payload["pages"] as? [[String: Any]])
        pages[0]["title"] = "\u{7814}\u{7A76} Ideas"
        payload["pages"] = pages
        let decoded = try JSONDecoder().decode(Notebook.self, from: JSONSerialization.data(withJSONObject: payload))
        XCTAssertEqual(try encodedPages(decoded)[0]["title"] as? String, "\u{7814}\u{7A76} Ideas")
        XCTAssertEqual(decoded.pages[0].markdown, page.markdown)
        XCTAssertEqual(decoded.pages[0].selectionLocation, 3)
        XCTAssertEqual(decoded.pages[0].selectionLength, 2)
    }

    @MainActor
    func testLoadingLegacyPagesAddsTitlesWithoutChangingNotes() async throws {
        let original = (0..<7).map { NotePage(markdown: "Original \($0)", selectionLocation: 2, selectionLength: 1) }
        let notebook = Notebook(schemaVersion: 1, pages: original, activePageID: original[3].id)
        let storage = StoreStorageSpy(loaded: .success(notebook))
        let store = NoteStore(storage: storage, saveDelay: .seconds(60))
        await store.load()
        await store.flush()
        let pages = try encodedPages(store.notebook)
        XCTAssertEqual(pages.compactMap { $0["title"] as? String }, ["Today", "Ideas", "Little things", "Note 4", "Note 5", "Note 6", "Note 7"])
        XCTAssertEqual(store.notebook.pages.map(\.id), original.map(\.id))
        XCTAssertEqual(store.notebook.pages.map(\.markdown), original.map(\.markdown))
        XCTAssertEqual(store.notebook.pages.map(\.modifiedAt), original.map(\.modifiedAt))
        XCTAssertEqual(store.activePage.id, original[3].id)
        XCTAssertEqual(store.activePage.selectionLocation, 2)
        XCTAssertEqual(store.activePage.selectionLength, 1)
        let saved = await storage.savedNotebooks()
        XCTAssertEqual(saved.last, store.notebook)
    }

    private func encodedPages(_ notebook: Notebook) throws -> [[String: Any]] {
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(notebook)) as? [String: Any])
        return try XCTUnwrap(payload["pages"] as? [[String: Any]])
    }
}
