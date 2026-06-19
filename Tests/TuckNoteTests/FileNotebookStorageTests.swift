import XCTest
@testable import TuckNote

final class FileNotebookStorageTests: XCTestCase {
    func testSaveThenLoadRoundTripsNotebook() async throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = FileNotebookStorage(baseDirectory: directory)
        var notebook = Notebook.blank()
        notebook.pages[0].markdown = "# Saved"

        try await storage.save(notebook)
        let loadedNotebook = try await storage.load()

        XCTAssertEqual(loadedNotebook, notebook)
    }

    func testMissingFileLoadsBlankNotebook() async throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = FileNotebookStorage(baseDirectory: directory)
        let loadedNotebook = try await storage.load()

        XCTAssertEqual(loadedNotebook.pages.count, 1)
    }

    func testCorruptFileIsPreservedAndThrowsRecoveryNotice() async throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appending(path: "notebook.json"))
        let storage = FileNotebookStorage(
            baseDirectory: directory,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        do {
            _ = try await storage.load()
            XCTFail("Expected corruptNotebookRecovered")
        } catch StorageError.corruptNotebookRecovered(let recovered) {
            let notebookURL = await storage.notebookURL
            XCTAssertEqual(
                recovered,
                directory.appending(path: "notebook-corrupt-2023-11-14T22:13:20Z.json")
            )
            XCTAssertTrue(FileManager.default.fileExists(atPath: recovered.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: notebookURL.path))
        }
    }

    private func temporaryDirectory(named testName: String) -> URL {
        let directoryName = testName.replacingOccurrences(of: "()", with: "")
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TuckNoteTests")
            .appending(path: directoryName)
        try? FileManager.default.removeItem(at: directory)
        return directory
    }
}
