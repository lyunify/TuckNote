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

    func testAddingPagesHasNoFixedLimit() {
        var notebook = Notebook.blank()
        for _ in 1..<40 { notebook.addPage() }
        XCTAssertEqual(notebook.pages.count, 40)
    }

    func testRemovingLastPageClearsItInsteadOfDeletingIt() {
        var notebook = Notebook.blank()
        notebook.pages[0].markdown = "keep me"
        notebook.removePage(id: notebook.pages[0].id)
        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.pages[0].markdown, "")
    }

    func testDecodingEmptyPagesIsRejected() throws {
        let payload = NotebookPayload(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: [],
            activePageID: UUID()
        )

        XCTAssertThrowsError(try JSONDecoder().decode(
            Notebook.self,
            from: JSONEncoder().encode(payload)
        ))
    }

    func testDecodingFutureSchemaVersionIsRejected() throws {
        let page = NotePage()
        let payload = NotebookPayload(
            schemaVersion: Notebook.currentSchemaVersion + 1,
            pages: [page],
            activePageID: page.id
        )

        XCTAssertThrowsError(try JSONDecoder().decode(
            Notebook.self,
            from: JSONEncoder().encode(payload)
        ))
    }

    func testDecodingManyPagesPreservesEveryPage() throws {
        let pages = (0..<40).map { _ in NotePage() }
        let payload = NotebookPayload(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: pages,
            activePageID: pages[0].id
        )

        XCTAssertEqual(try JSONDecoder().decode(
            Notebook.self,
            from: JSONEncoder().encode(payload)
        ).pages, pages)
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

    func testConstructingManyPagesPreservesPagesAndActiveID() {
        let pages = (0..<40).map { _ in NotePage() }

        let notebook = Notebook(
            schemaVersion: Notebook.currentSchemaVersion,
            pages: pages,
            activePageID: pages.last!.id
        )

        XCTAssertEqual(notebook.pages, pages)
        XCTAssertEqual(notebook.activePageID, pages.last!.id)
    }

    func testAssigningEmptyPagesRecoversOneBlankActivePage() {
        var notebook = Notebook.blank()

        notebook.pages = []

        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.activePageID, notebook.pages.first?.id)
        XCTAssertEqual(notebook.pages.first?.markdown, "")
    }

    func testAssigningManyPagesPreservesAllPagesAndValidActivePage() {
        var notebook = Notebook.blank()
        let pages = (0..<40).map { _ in NotePage() }

        notebook.pages = pages

        XCTAssertEqual(notebook.pages, pages)
        XCTAssertEqual(notebook.activePageID, pages[0].id)
        XCTAssertTrue(notebook.pages.contains { $0.id == notebook.activePageID })
    }

    func testRemovingUnknownIDFromSinglePageNotebookIsNoOp() {
        var notebook = Notebook.blank()
        notebook.pages[0].markdown = "keep me"
        let original = notebook

        notebook.removePage(id: UUID())

        XCTAssertEqual(notebook, original)
    }

    func testAssigningUnknownActivePageIDKeepsAValidActivePage() {
        var notebook = Notebook.blank()
        let originalActivePageID = notebook.activePageID

        notebook.activePageID = UUID()

        XCTAssertEqual(notebook.activePageID, originalActivePageID)
        XCTAssertTrue(notebook.pages.contains { $0.id == notebook.activePageID })
    }
}
