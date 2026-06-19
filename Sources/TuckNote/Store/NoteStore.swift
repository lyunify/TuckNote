import Combine
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notebook: Notebook
    @Published private(set) var notice: String?
    @Published private(set) var isSaving = false

    private let storage: any NotebookStorage
    private let saveDelay: ContinuousClock.Duration
    private var saveTask: Task<Void, Never>?

    init(
        storage: any NotebookStorage,
        saveDelay: ContinuousClock.Duration = .milliseconds(500)
    ) {
        self.storage = storage
        self.saveDelay = saveDelay
        notebook = .blank()
    }

    var activePage: NotePage {
        notebook.pages.first(where: { $0.id == notebook.activePageID }) ?? notebook.pages[0]
    }

    func load() async {
        saveTask?.cancel()
        saveTask = nil
        notice = nil

        do {
            notebook = try await storage.load()
        } catch StorageError.corruptNotebookRecovered {
            notebook = .blank()
            notice = "Recovered a damaged notebook."
        } catch {
            notebook = .blank()
            notice = "Could not load notes."
        }
    }

    func updateMarkdown(_ markdown: String) {
        guard let index = activePageIndex else { return }
        notebook.pages[index].markdown = markdown
        notebook.pages[index].modifiedAt = .now
        clampSelection(at: index)
        scheduleSave()
    }

    func selectPage(_ id: UUID) {
        guard notebook.pages.contains(where: { $0.id == id }) else { return }
        notebook.activePageID = id
        scheduleSave()
    }

    func addPage() {
        do {
            try notebook.addPage()
            scheduleSave()
        } catch NotebookError.pageLimitReached {
            notice = "You can keep up to five pages."
        } catch {
            notice = "Could not add a page."
        }
    }

    func removeActivePage() {
        notebook.removePage(id: notebook.activePageID)
        scheduleSave()
    }

    func updateSelection(location: Int, length: Int) {
        guard let index = activePageIndex else { return }
        let utf16Length = (notebook.pages[index].markdown as NSString).length
        let location = min(max(location, 0), utf16Length)
        notebook.pages[index].selectionLocation = location
        notebook.pages[index].selectionLength = min(max(length, 0), utf16Length - location)
        scheduleSave()
    }

    func flush() async {
        saveTask?.cancel()
        saveTask = nil
        await saveNow()
    }

    private var activePageIndex: Int? {
        notebook.pages.firstIndex(where: { $0.id == notebook.activePageID })
    }

    private func clampSelection(at index: Int) {
        let utf16Length = (notebook.pages[index].markdown as NSString).length
        let location = min(max(notebook.pages[index].selectionLocation, 0), utf16Length)
        notebook.pages[index].selectionLocation = location
        notebook.pages[index].selectionLength = min(
            max(notebook.pages[index].selectionLength, 0),
            utf16Length - location
        )
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let delay = saveDelay
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.saveTask = nil
            await self.saveNow()
        }
    }

    private func saveNow() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await storage.save(notebook)
        } catch {
            notice = "Could not save notes."
        }
    }
}
