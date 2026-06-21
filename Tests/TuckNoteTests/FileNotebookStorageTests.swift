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
        let corruptData = Data("not-json".utf8)
        try corruptData.write(to: directory.appending(path: "notebook.json"))
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
            XCTAssertEqual(try Data(contentsOf: recovered), corruptData)
            XCTAssertFalse(FileManager.default.fileExists(atPath: notebookURL.path))
        }
    }

    func testCorruptFileRecoveryDoesNotOverwriteExistingRecovery() async throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let corruptData = Data([0x00, 0xFF, 0x10, 0x80])
        try corruptData.write(to: directory.appending(path: "notebook.json"))
        let existingRecovery = directory.appending(
            path: "notebook-corrupt-2023-11-14T22:13:20Z.json"
        )
        let existingData = Data("earlier recovery".utf8)
        try existingData.write(to: existingRecovery)
        let storage = FileNotebookStorage(
            baseDirectory: directory,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        do {
            _ = try await storage.load()
            XCTFail("Expected corruptNotebookRecovered")
        } catch StorageError.corruptNotebookRecovered(let recovered) {
            XCTAssertNotEqual(recovered, existingRecovery)
            XCTAssertEqual(try Data(contentsOf: existingRecovery), existingData)
            XCTAssertEqual(try Data(contentsOf: recovered), corruptData)
        }
    }

    func testUnsupportedSchemaFileIsPreservedForRecovery() async throws {
        let directory = temporaryDirectory(named: #function)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let notebookURL = directory.appending(path: "notebook.json")
        let data = Data("""
        {"schemaVersion":2,"pages":[],"activePageID":"00000000-0000-0000-0000-000000000000"}
        """.utf8)
        try data.write(to: notebookURL)
        let storage = FileNotebookStorage(baseDirectory: directory)

        do {
            _ = try await storage.load()
            XCTFail("Expected corruptNotebookRecovered")
        } catch StorageError.corruptNotebookRecovered(let recovered) {
            XCTAssertEqual(try Data(contentsOf: recovered), data)
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
