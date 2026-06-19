import Foundation

struct NotePage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var markdown: String
    var modifiedAt: Date
    var selectionLocation: Int
    var selectionLength: Int

    init(id: UUID = UUID(), markdown: String = "", modifiedAt: Date = .now,
         selectionLocation: Int = 0, selectionLength: Int = 0) {
        self.id = id
        self.markdown = markdown
        self.modifiedAt = modifiedAt
        self.selectionLocation = selectionLocation
        self.selectionLength = selectionLength
    }
}

enum NotebookError: Error, Equatable { case pageLimitReached }

struct Notebook: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let maximumPageCount = 5
    var schemaVersion: Int
    var pages: [NotePage]
    var activePageID: UUID

    init(schemaVersion: Int, pages: [NotePage], activePageID: UUID) {
        self.schemaVersion = schemaVersion
        self.pages = Array(pages.prefix(Self.maximumPageCount))
        if self.pages.isEmpty {
            self.pages = [NotePage()]
        }
        self.activePageID = self.pages.contains(where: { $0.id == activePageID })
            ? activePageID
            : self.pages[0].id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            pages: try container.decode([NotePage].self, forKey: .pages),
            activePageID: try container.decode(UUID.self, forKey: .activePageID)
        )
    }

    static func blank() -> Notebook {
        let page = NotePage()
        return Notebook(schemaVersion: currentSchemaVersion, pages: [page], activePageID: page.id)
    }

    mutating func addPage() throws {
        guard pages.count < Self.maximumPageCount else { throw NotebookError.pageLimitReached }
        let page = NotePage()
        pages.append(page)
        activePageID = page.id
    }

    mutating func removePage(id: UUID) {
        guard pages.count > 1 else {
            pages[0] = NotePage(id: pages[0].id)
            activePageID = pages[0].id
            return
        }
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages.remove(at: index)
        activePageID = pages[min(index, pages.count - 1)].id
    }
}
