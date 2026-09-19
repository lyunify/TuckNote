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

struct Notebook: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    private var storedPages: [NotePage]
    private var storedActivePageID: UUID
    var pages: [NotePage] {
        get { storedPages }
        set {
            storedPages = Self.normalizedPages(newValue)
            if !storedPages.contains(where: { $0.id == storedActivePageID }) {
                storedActivePageID = storedPages[0].id
            }
        }
    }
    var activePageID: UUID {
        get { storedActivePageID }
        set {
            if storedPages.contains(where: { $0.id == newValue }) {
                storedActivePageID = newValue
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, pages, activePageID
    }

    init(schemaVersion: Int, pages: [NotePage], activePageID: UUID) {
        self.schemaVersion = schemaVersion
        storedPages = Self.normalizedPages(pages)
        storedActivePageID = storedPages.contains(where: { $0.id == activePageID })
            ? activePageID
            : storedPages[0].id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported notebook schema version \(schemaVersion)."
            )
        }
        let pages = try container.decode([NotePage].self, forKey: .pages)
        guard !pages.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .pages,
                in: container,
                debugDescription: "Notebook must contain at least one page."
            )
        }
        self.init(
            schemaVersion: schemaVersion,
            pages: pages,
            activePageID: try container.decode(UUID.self, forKey: .activePageID)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(storedPages, forKey: .pages)
        try container.encode(storedActivePageID, forKey: .activePageID)
    }

    static func blank() -> Notebook {
        let page = NotePage()
        return Notebook(schemaVersion: currentSchemaVersion, pages: [page], activePageID: page.id)
    }

    mutating func addPage() {
        let page = NotePage()
        pages.append(page)
        activePageID = page.id
    }

    mutating func removePage(id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        guard pages.count > 1 else {
            pages[0] = NotePage(id: pages[0].id)
            activePageID = pages[0].id
            return
        }
        pages.remove(at: index)
        activePageID = pages[min(index, pages.count - 1)].id
    }

    private static func normalizedPages(_ pages: [NotePage]) -> [NotePage] {
        return pages.isEmpty ? [NotePage()] : pages
    }
}
