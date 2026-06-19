import XCTest
@testable import TuckNote

private struct NotebookPayload: Encodable {
    let schemaVersion: Int
    let pages: [NotePage]
    let activePageID: UUID
}

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

    func testDecodingEmptyPagesRecoversOneBlankActivePage() throws {
        let payload = NotebookPayload(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: [],
            activePageID: UUID()
        )

        let notebook = try JSONDecoder().decode(
            Notebook.self,
            from: JSONEncoder().encode(payload)
        )

        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.activePageID, notebook.pages.first?.id)
        XCTAssertEqual(notebook.pages.first?.markdown, "")
    }

    func testDecodingInvalidActivePageIDActivatesFirstPage() throws {
        let firstPage = NotePage()
        let payload = NotebookPayload(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: [firstPage, NotePage()],
            activePageID: UUID()
        )

        let notebook = try JSONDecoder().decode(
            Notebook.self,
            from: JSONEncoder().encode(payload)
        )

        XCTAssertEqual(notebook.activePageID, firstPage.id)
    }

    func testConstructingMoreThanMaximumPagesKeepsFirstFive() {
        let pages = (0...Notebook.maximumPageCount).map { _ in NotePage() }

        let notebook = Notebook(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: pages,
            activePageID: pages.last!.id
        )

        XCTAssertEqual(notebook.pages.count, Notebook.maximumPageCount)
        XCTAssertEqual(notebook.activePageID, pages[0].id)
    }
}
