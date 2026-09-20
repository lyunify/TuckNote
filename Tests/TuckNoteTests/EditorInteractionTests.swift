import AppKit
import SwiftUI
import XCTest
@testable import TuckNote

@MainActor
final class EditorInteractionTests: XCTestCase {
    func testTaskGeometryStaysStableDuringChineseComposition() async throws {
        let fixture = try await EditorFixture("- [ ] ")
        defer { fixture.close() }
        fixture.editor.setSelectedRange(NSRange(location: 6, length: 0))
        await fixture.settle()
        let original = try XCTUnwrap(fixture.editor.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let checkbox = fixture.editor.firstRect(forCharacterRange: NSRange(location: 2, length: 3), actualRange: nil)
        for candidate in ["n", "ni", "ni hao", "\u{4F60}\u{597D}"] {
            fixture.editor.setMarkedText(candidate, selectedRange: NSRange(location: candidate.utf16.count, length: 0),
                                         replacementRange: NSRange(location: NSNotFound, length: 0))
            XCTAssertTrue(fixture.editor.hasMarkedText())
            let style = try XCTUnwrap(fixture.editor.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            XCTAssertEqual(style.firstLineHeadIndent, original.firstLineHeadIndent, accuracy: 0.1)
            XCTAssertEqual(style.headIndent, original.headIndent, accuracy: 0.1)
            XCTAssertEqual(style.minimumLineHeight, original.minimumLineHeight, accuracy: 0.1)
            XCTAssertEqual(style.maximumLineHeight, original.maximumLineHeight, accuracy: 0.1)
            XCTAssertEqual(style.paragraphSpacing, original.paragraphSpacing, accuracy: 0.1)
            await fixture.settle()
            XCTAssertTrue(fixture.editor.hasMarkedText())
            XCTAssertEqual(fixture.editor.string, "- [ ] " + candidate)
            let currentCheckbox = fixture.editor.firstRect(forCharacterRange: NSRange(location: 2, length: 3), actualRange: nil)
            XCTAssertEqual(currentCheckbox.minX, checkbox.minX, accuracy: 0.5)
            XCTAssertEqual(currentCheckbox.minY, checkbox.minY, accuracy: 0.5)
        }
        fixture.editor.insertText("\u{4F60}\u{597D}", replacementRange: fixture.editor.markedRange())
        await fixture.settle()
        XCTAssertFalse(fixture.editor.hasMarkedText())
        XCTAssertEqual(fixture.store.activePage.markdown, "- [ ] \u{4F60}\u{597D}")
    }

    func testToolbarBoldTogglesAndKeyboardItalicKeepsUnicodeSelection() async throws {
        for prefix in ["", "- ", "- [ ] "] {
            let sentence = "A \u{1F4DD} sentence"
            let fixture = try await EditorFixture(prefix + sentence)
            defer { fixture.close() }
            fixture.editor.setSelectedRange(NSRange(location: prefix.utf16.count, length: sentence.utf16.count))
            await fixture.settle()
            XCTAssertTrue(fixture.pressToolbar("Bold"))
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, prefix + "**" + sentence + "**")
            XCTAssertEqual(fixture.editor.selectedRange(), NSRange(location: prefix.utf16.count + 2, length: sentence.utf16.count))
            let font = try XCTUnwrap(fixture.editor.textStorage?.attribute(.font, at: prefix.utf16.count + 2, effectiveRange: nil) as? NSFont)
            XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
            let markerFont = try XCTUnwrap(fixture.editor.textStorage?.attribute(.font, at: prefix.utf16.count, effectiveRange: nil) as? NSFont)
            XCTAssertLessThan(markerFont.pointSize, 1)
            try fixture.snapshotIfRequested("bold-\(prefix.utf16.count)")
            XCTAssertTrue(fixture.pressToolbar("Bold"))
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, prefix + sentence)
            XCTAssertTrue(fixture.command("i"))
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, prefix + "*" + sentence + "*")
            XCTAssertTrue(fixture.command("i"))
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, prefix + sentence)
            XCTAssertEqual(fixture.store.activePage.markdown, fixture.editor.string)
        }
    }

    func testEmptyBoldToggleAndUndo() async throws {
        let fixture = try await EditorFixture("")
        defer { fixture.close() }
        XCTAssertTrue(fixture.pressToolbar("Bold"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "****")
        XCTAssertEqual(fixture.editor.selectedRange(), NSRange(location: 2, length: 0))
        XCTAssertTrue(fixture.pressToolbar("Bold"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "")
        fixture.editor.insertText("A sentence", replacementRange: fixture.editor.selectedRange())
        await fixture.settle()
        fixture.editor.selectAll(nil)
        XCTAssertTrue(fixture.command("b"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "**A sentence**")
        XCTAssertTrue(fixture.command("z"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "A sentence")
        XCTAssertEqual(fixture.store.activePage.markdown, "A sentence")
    }

    func testBoldTypingThenToggleOffKeepsTextVisible() async throws {
        let fixture = try await EditorFixture("")
        defer { fixture.close() }
        XCTAssertTrue(fixture.command("b"))
        await fixture.settle()
        fixture.editor.insertText("New thought", replacementRange: fixture.editor.selectedRange())
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "**New thought**")
        let font = try XCTUnwrap(fixture.editor.textStorage?.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)
        XCTAssertGreaterThan(font.pointSize, 1)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(fixture.command("b"))
        await fixture.settle()
        XCTAssertEqual(fixture.editor.string, "New thought")
        fixture.editor.insertText(" continues", replacementRange: fixture.editor.selectedRange())
        await fixture.settle()
        XCTAssertEqual(fixture.store.activePage.markdown, "New thought continues")
    }

    func testCommandBTogglesSelectedSentencesAndPreservesListSyntax() async throws {
        for prefix in ["", "- ", "- [ ] "] {
            let fixture = try await EditorFixture(prefix + "A sentence")
            defer { fixture.close() }
            fixture.editor.setSelectedRange(NSRange(location: prefix.utf16.count, length: 10))
            XCTAssertTrue(fixture.command("b"))
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, prefix + "**A sentence**")
            XCTAssertEqual(fixture.store.activePage.markdown, fixture.editor.string)
            let font = try XCTUnwrap(fixture.editor.textStorage?.attribute(.font, at: prefix.utf16.count + 3, effectiveRange: nil) as? NSFont)
            XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
            XCTAssertTrue(fixture.command("b"))
            await fixture.settle()
            XCTAssertEqual(fixture.editor.string, prefix + "A sentence")
            XCTAssertEqual(fixture.editor.selectedRange(), NSRange(location: prefix.utf16.count, length: 10))
        }
    }

    func testRefinedLightHeadingUsesCompactScale() async throws {
        let fixture = try await EditorFixture("# Heading\n\nBody")
        defer { fixture.close() }
        let font = try XCTUnwrap(fixture.editor.textStorage?.attribute(.font, at: 3, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(font.pointSize, 23, accuracy: 0.1)
    }

    func testNamedPagesKeepEditorUsableAtDefaultAndMinimumSizes() async throws {
        let sample = "# A little room to think\n\nSmall notes. A clearer day.\n\n- [x] Send the draft\n- [ ] Refine one small detail\n- [ ] Leave space for a new idea\n\n- Keep the useful things close.\n\n[Read later](https://example.com)\n\n"
        let fixture = try await EditorFixture(sample, pageCount: 7)
        defer { fixture.close() }
        let first = fixture.store.activePage.id
        fixture.store.selectPage(first)
        for mode in [ThemeMode.light, .dark] {
            fixture.settings.themeMode = mode
            for size in [NSSize(width: 520, height: 430), NSSize(width: 360, height: 260)] {
                fixture.window.setContentSize(size)
                await fixture.settle()
                fixture.refreshEditor()
                fixture.editor.setSelectedRange(NSRange(location: sample.utf16.count, length: 0))
                await fixture.settle()
                XCTAssertEqual(fixture.editor.string, sample)
                let scrollView = try XCTUnwrap(fixture.editor.enclosingScrollView)
                XCTAssertLessThanOrEqual(scrollView.frame.width, size.width)
                XCTAssertGreaterThan(scrollView.frame.height, 90)
                let root = try XCTUnwrap(fixture.window.contentView)
                let editorRect = scrollView.convert(scrollView.bounds, to: root)
                let topGap = root.isFlipped ? editorRect.minY : root.bounds.height - editorRect.maxY
                let bottomGap = root.isFlipped ? root.bounds.height - editorRect.maxY : editorRect.minY
                XCTAssertEqual(topGap, 88, accuracy: 1)
                XCTAssertEqual(bottomGap, 38, accuracy: 1)
                try fixture.snapshotIfRequested("\(mode.rawValue)-\(Int(size.width))")
            }
        }
        fixture.store.renamePage(first, to: "A very long page name that needs truncation")
        for _ in 0..<10 { fixture.store.addPage() }
        await fixture.settle()
        fixture.refreshEditor()
        fixture.editor.insertText("Last page", replacementRange: fixture.editor.selectedRange())
        await fixture.settle()
        XCTAssertEqual(fixture.store.activePage.markdown, "Last page")
        fixture.store.selectPage(first)
        await fixture.settle()
        fixture.refreshEditor()
        XCTAssertEqual(fixture.editor.string, sample)
        XCTAssertEqual(fixture.store.activePage.title?.count, 40)
    }

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

    init(_ text: String, pageCount: Int = 1) async throws {
        _ = NSApplication.shared
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pages = (0..<pageCount).map { _ in NotePage() }
        let notebook = Notebook(schemaVersion: 1, pages: pages, activePageID: pages[0].id)
        let storage = StoreStorageSpy(loaded: .success(notebook))
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

    func pressToolbar(_ label: String) -> Bool {
        guard label == "Bold", let root = window.contentView else { return false }
        // The first toolbar button is centered 27 points from the left, in the 38-point footer.
        let point = root.convert(NSPoint(x: 27, y: root.isFlipped ? root.bounds.height - 19 : 19), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            window.sendEvent(event)
        }
        return true
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

    func snapshotIfRequested(_ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["TUCKNOTES_SNAPSHOT_DIR"],
              let view = window.contentView else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        view.displayIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
