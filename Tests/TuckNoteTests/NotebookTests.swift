import XCTest
@testable import TuckNote

final class NotebookTests: XCTestCase {
    func testBlankNotebookHasOneActiveEmptyPage() {
        let notebook = Notebook.blank()
        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.activePageID, notebook.pages[0].id)
        XCTAssertEqual(notebook.pages[0].markdown, "")
    }

    func testAddingSixthPageThrowsLimitReached() throws {
        var notebook = Notebook.blank()
        for _ in 1..<Notebook.maximumPageCount { try notebook.addPage() }
        XCTAssertThrowsError(try notebook.addPage()) { error in
            XCTAssertEqual(error as? NotebookError, .pageLimitReached)
        }
    }

    func testRemovingLastPageClearsItInsteadOfDeletingIt() {
        var notebook = Notebook.blank()
        notebook.pages[0].markdown = "keep me"
        notebook.removePage(id: notebook.pages[0].id)
        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.pages[0].markdown, "")
    }
}
