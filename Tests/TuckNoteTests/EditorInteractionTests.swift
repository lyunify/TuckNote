import AppKit
import SwiftUI
import XCTest
@testable import TuckNote

@MainActor
final class EditorInteractionTests: XCTestCase {
    func testOneBackspaceRemovesEmptyListPrefixWithoutRevealingSource() async throws {
        for prefix in ["- ", "- [ ] ", "1. ", "\t- [x] "] {
            let fixture = try await EditorFixture(prefix)
            defer { fixture.close() }
            fixture.editor.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                        windowNumber: fixture.window.windowNumber, context: nil, characters: "\u{7f}",
                                        charactersIgnoringModifiers: "\u{7f}", isARepeat: false, keyCode: 51)!
            fixture.window.sendEvent(event)
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, "", prefix)
            XCTAssertEqual(fixture.editor.selectedRange(), NSRange(location: 0, length: 0))
            XCTAssertEqual(fixture.store.activePage.markdown, "")
            XCTAssertTrue(fixture.command("z"))
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, prefix)
            XCTAssertEqual(fixture.store.activePage.markdown, prefix)
        }
    }

    func testThemeSwitchRecreatesStylingWithoutLosingText() async throws {
        let fixture = try await EditorFixture("text\n\n---\n\n- [ ] task")
        defer { fixture.close() }
        for mode in [ThemeMode.dark, .light] {
            fixture.settings.themeMode = mode
            await fixture.settle()
            fixture.refreshEditor()
            XCTAssertEqual(fixture.editor.string, "text\n\n---\n\n- [ ] task")
            let color = fixture.editor.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
            XCTAssertEqual(color?.usingColorSpace(.sRGB), NSColor(TuckNoteTheme.palette(for: mode).ink).usingColorSpace(.sRGB))
        }
    }

    func testCommandSelectCopyCutPasteAndUndoInPanel() async throws {
        let fixture = try await EditorFixture("- [ ] study\n- second")
        defer { fixture.close() }
        let pasteboard = NSPasteboard.general
        let savedItems = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        defer {
            pasteboard.clearContents()
            pasteboard.writeObjects(savedItems)
        }
        XCTAssertTrue(fixture.command("a"))
        XCTAssertEqual(fixture.editor.selectedRange(), NSRange(location: 0, length: 20))
        XCTAssertTrue(fixture.command("c"))
        XCTAssertEqual(pasteboard.string(forType: .string), "- [ ] study\n- second")
        XCTAssertTrue(fixture.command("x"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "")
        XCTAssertTrue(fixture.command("v"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "- [ ] study\n- second")
        fixture.command("a")
        fixture.editor.deleteBackward(nil)
        await fixture.settle()
        XCTAssertEqual(fixture.store.activePage.markdown, "")
        XCTAssertTrue(fixture.command("z"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "- [ ] study\n- second")
    }

    func testBackspaceCanRemoveWholeTaskIncludingItsPrefix() async throws {
        let fixture = try await EditorFixture("- [ ] task")
        defer { fixture.close() }
        fixture.editor.setSelectedRange(NSRange(location: 10, length: 0))
        for _ in 0..<10 {
            fixture.editor.deleteBackward(nil)
            await fixture.settle()
        }
        XCTAssertEqual(fixture.editor.string, "")
        XCTAssertEqual(fixture.store.activePage.markdown, "")
    }

    func testAppearanceRefreshDoesNotRevealBulletOrRuleMarkers() async throws {
        let fixture = try await EditorFixture("- item\n\n---\n\ntext")
        defer { fixture.close() }
        fixture.editor.setSelectedRange(NSRange(location: fixture.editor.string.utf16.count, length: 0))
        await fixture.settle()
        for _ in 0..<4 {
            MarkdownEditorAppearance.tuckNote().apply(to: fixture.editor)
            await fixture.settle()
            XCTAssertEqual((fixture.editor.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?.alphaComponent, 0)
            XCTAssertEqual((fixture.editor.textStorage?.attribute(.foregroundColor, at: 8, effectiveRange: nil) as? NSColor)?.alphaComponent, 0)
        }
    }

    func testSelectAllDeletesMixedMarkdownInOneEdit() async throws {
        let fixture = try await EditorFixture("- first\n- [ ] task\n\n---\n\n**bold**\n\u{4E2D}\u{6587}")
        defer { fixture.close() }
        fixture.editor.selectAll(nil)
        XCTAssertEqual(fixture.editor.selectedRange().length, fixture.editor.string.utf16.count)
        fixture.editor.deleteBackward(nil)
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "")
        XCTAssertEqual(fixture.store.activePage.markdown, "")
    }

    func testTypingTaskKeepsSelectionAndDecorationStable() async throws {
        let fixture = try await EditorFixture("- [ ] task")
        defer { fixture.close() }
        fixture.editor.setSelectedRange(NSRange(location: 10, length: 0))
        for character in " hello\u{4E2D}\u{6587}" {
            fixture.editor.insertText(String(character), replacementRange: fixture.editor.selectedRange())
            await fixture.settle()
            XCTAssertEqual(fixture.editor.selectedRange(), NSRange(location: fixture.editor.string.utf16.count, length: 0))
            XCTAssertEqual(fixture.editor.textStorage?.attribute(NSAttributedString.Key("TaskCheckbox"), at: 2, effectiveRange: nil) as? Bool, false)
        }
        XCTAssertEqual(fixture.store.activePage.markdown, "- [ ] task hello\u{4E2D}\u{6587}")
    }

    func testRuleRevealsSourceWithoutKeepingRenderedLine() async throws {
        let fixture = try await EditorFixture("---\n\ntext")
        defer { fixture.close() }
        fixture.editor.setSelectedRange(NSRange(location: 9, length: 0))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.textStorage?.attribute(NSAttributedString.Key("ThematicBreak"), at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(fixture.firstRenderedColor()?.alphaComponent, 0)
        fixture.editor.setSelectedRange(NSRange(location: 1, length: 0))
        await fixture.settle()
        XCTAssertNil(fixture.editor.textStorage?.attribute(NSAttributedString.Key("ThematicBreak"), at: 0, effectiveRange: nil))
        XCTAssertEqual(fixture.firstRenderedColor()?.alphaComponent, 1)
    }

    func testSwitchBetweenEmptyPagesThenTypeIntoEach() async throws {
        let fixture = try await EditorFixture("")
        defer { fixture.close() }
        let firstID = fixture.store.activePage.id
        fixture.store.addPage()
        await fixture.settle()
        fixture.refreshEditor()
        fixture.editor.insertText("second", replacementRange: fixture.editor.selectedRange())
        await fixture.settle()
        fixture.store.selectPage(firstID)
        await fixture.settle()
        fixture.refreshEditor()
        XCTAssertEqual(fixture.editor.string, "")
        fixture.editor.insertText("first", replacementRange: fixture.editor.selectedRange())
        await fixture.settle()
        XCTAssertEqual(fixture.store.notebook.pages.map(\.markdown), ["first", "second"])
    }
}

@MainActor
private final class EditorFixture {
    let store: NoteStore
    let window: NSWindow
    let directory: URL
    let settings = AppSettings(defaults: UserDefaults(suiteName: "TuckNote.EditorTests")!)
    private(set) var editor: NSTextView!

    init(_ text: String) async throws {
        _ = NSApplication.shared
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = StoreStorageSpy()
        store = NoteStore(storage: storage, saveDelay: .seconds(60))
        await store.load()
        store.updateMarkdown(text)
        window = NotchPanel(contentRect: NSRect(x: 100, y: 100, width: 480, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        settings.themeMode = .light
        window.contentView = NSHostingView(rootView: NotebookView(store: store, settings: settings, imageStore: ImageStore(baseDirectory: directory)))
        window.makeKeyAndOrderFront(nil)
        await settle()
        refreshEditor()
        XCTAssertNotNil(editor)
        window.makeFirstResponder(editor)
    }

    func refreshEditor() {
        func find(_ view: NSView) -> NSTextView? {
            if let editor = view as? NSTextView { return editor }
            return view.subviews.lazy.compactMap(find).first
        }
        editor = window.contentView.flatMap(find)
    }

    @discardableResult
    func command(_ key: String) -> Bool {
        window.makeFirstResponder(editor)
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                    windowNumber: window.windowNumber, context: nil, characters: key,
                                    charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0)!
        return window.performKeyEquivalent(with: event)
    }

    func settle() async {
        try? await Task.sleep(for: .milliseconds(80))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func firstRenderedColor() -> NSColor? {
        guard let manager = editor.textLayoutManager else { return nil }
        var color: NSColor?
        manager.enumerateTextLayoutFragments(from: manager.documentRange.location, options: [.ensuresLayout]) { fragment in
            color = fragment.textLineFragments.first?.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
            return false
        }
        return color
    }

    func close() {
        window.close()
        try? FileManager.default.removeItem(at: directory)
    }
}
