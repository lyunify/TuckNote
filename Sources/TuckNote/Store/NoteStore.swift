import Combine
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notebook: Notebook
    @Published private(set) var notice: String?
    @Published private(set) var isSaving = false
    @Published private(set) var isLoaded = false

    private let storage: any NotebookStorage
    private let saveDelay: ContinuousClock.Duration
    private let onFlushWaitingForSave: (() -> Void)?
    private var saveTask: Task<Void, Never>?
    private var isDirty = false
    private var saveCompletionWaiters: [CheckedContinuation<Bool, Never>] = []

    init(
        storage: any NotebookStorage,
        saveDelay: ContinuousClock.Duration = .milliseconds(500),
        onFlushWaitingForSave: (() -> Void)? = nil
    ) {
        self.storage = storage
        self.saveDelay = saveDelay
        self.onFlushWaitingForSave = onFlushWaitingForSave
        notebook = .blank()
    }

    var activePage: NotePage {
        notebook.pages.first(where: { $0.id == notebook.activePageID }) ?? notebook.pages[0]
    }

    func load() async {
        saveTask?.cancel()
        saveTask = nil
        isDirty = false
        isLoaded = false
        notice = nil
        defer { isLoaded = true }

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

    func showNotice(_ message: String) {
        notice = message
    }

    func dismissNotice() {
        notice = nil
    }

    @discardableResult
    func flush() async -> Bool {
        while isSaving || isDirty {
            saveTask?.cancel()
            saveTask = nil

            if isSaving {
                guard await waitForSaveCompletion() else { return false }
            } else {
                guard await saveIfNeeded() else { return false }
            }
        }
        return true
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
        isDirty = true
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
            _ = await self.saveIfNeeded()
        }
    }

    private func saveIfNeeded() async -> Bool {
        guard !isSaving, isDirty else { return true }
        isDirty = false
        isSaving = true
        let snapshot = notebook

        let didSave: Bool
        do {
            try await storage.save(snapshot)
            didSave = true
        } catch {
            isDirty = true
            notice = "Could not save notes."
            didSave = false
        }

        isSaving = false
        let waiters = saveCompletionWaiters
        saveCompletionWaiters.removeAll()
        waiters.forEach { $0.resume(returning: didSave) }

        if didSave, isDirty {
            scheduleSave()
        }
        return didSave
    }

    private func waitForSaveCompletion() async -> Bool {
        guard isSaving else { return true }
        return await withCheckedContinuation {
            saveCompletionWaiters.append($0)
            onFlushWaitingForSave?()
        }
    }
}
