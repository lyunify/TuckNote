import Foundation

protocol NotebookStorage: Sendable {
    func load() async throws -> Notebook
    func save(_ notebook: Notebook) async throws
}

enum StorageError: Error {
    case corruptNotebookRecovered(URL)
}

actor FileNotebookStorage: NotebookStorage {
    let baseDirectory: URL
    let notebookURL: URL
    private let fileManager: FileManager
    private let now: @Sendable () -> Date

    init(
        baseDirectory: URL,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.baseDirectory = baseDirectory
        notebookURL = baseDirectory.appending(path: "notebook.json")
        self.fileManager = fileManager
        self.now = now
    }

    func load() throws -> Notebook {
        guard fileManager.fileExists(atPath: notebookURL.path) else { return .blank() }

        do {
            let data = try Data(contentsOf: notebookURL)
            return try JSONDecoder().decode(Notebook.self, from: data)
        } catch {
            let formatter = ISO8601DateFormatter()
            let recovered = baseDirectory.appending(
                path: "notebook-corrupt-\(formatter.string(from: now())).json"
            )
            try fileManager.moveItem(at: notebookURL, to: recovered)
            throw StorageError.corruptNotebookRecovered(recovered)
        }
    }

    func save(_ notebook: Notebook) throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(notebook)
        try data.write(to: notebookURL, options: .atomic)
    }
}
