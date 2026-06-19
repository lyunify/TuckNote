import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()

    private var statusItem: NSStatusItem?
    private var storage: FileNotebookStorage?
    private var imageStore: ImageStore?
    private var noteStore: NoteStore?
    private var panelController: NotchPanelController?
    private let shortcutService = GlobalShortcutService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "TuckNote", directoryHint: .isDirectory)
        let storage = FileNotebookStorage(baseDirectory: baseDirectory)
        let imageStore = ImageStore(baseDirectory: baseDirectory)
        let noteStore = NoteStore(storage: storage)
        let panelController = NotchPanelController(
            store: noteStore,
            imageStore: imageStore,
            settings: settings
        )

        self.storage = storage
        self.imageStore = imageStore
        self.noteStore = noteStore
        self.panelController = panelController
        shortcutService.start { [weak panelController] in
            panelController?.toggle()
        }

        buildStatusItem()
        Task {
            await noteStore.load()
            panelController.showCompact()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let noteStore else { return .terminateNow }
        Task {
            await noteStore.flush()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutService.stop()
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "note.text",
            accessibilityDescription: "TuckNote"
        )
        let menu = NSMenu()
        menu.addItem(withTitle: "Show", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Hide", action: #selector(hidePanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TuckNote", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func showPanel() {
        NSApp.unhide(nil)
        panelController?.showCompact()
    }

    @objc private func hidePanel() {
        NSApp.hide(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
