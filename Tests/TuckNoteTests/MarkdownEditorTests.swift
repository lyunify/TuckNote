import AppKit
import XCTest
@testable import TuckNote

final class MarkdownEditorTests: XCTestCase {
    @MainActor
    func testAtomicListDeletionDoesNotChangeLiteralCodeOrBodyText() {
        for (source, caret) in [("```\n- \n```", 6), ("~~~md\n- [ ] \n~~~", 12), ("- body", 5)] {
            let editor = NSTextView()
            editor.string = source
            editor.setSelectedRange(NSRange(location: caret, length: 0))
            XCTAssertFalse(MarkdownListPrefix.deleteBackward(in: editor))
            XCTAssertEqual(editor.string, source)
        }
    }

    func testListToolbarPreservesUnicodeSelectionAcrossMultipleLines() throws {
        let text = "\u{4E2D}\u{6587}\nhello"
        let edit = try XCTUnwrap(MarkdownSelectionEdit.make(command: .task, text: text, selection: NSRange(location: 0, length: text.utf16.count)))
        XCTAssertEqual(edit.replacement, "- [ ] \u{4E2D}\u{6587}\n- [ ] hello")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 6, length: 14))
        let toggle = try XCTUnwrap(MarkdownSelectionEdit.make(command: .task, text: edit.replacement, selection: edit.selectedRange))
        XCTAssertEqual(toggle.replacement, text)
        XCTAssertEqual(toggle.selectedRange, NSRange(location: 0, length: text.utf16.count))
    }

    func testListToolbarLeavesCaretAfterEmptyMarker() throws {
        for (command, prefix) in [(MarkdownToolbarCommand.bullet, "- "), (.task, "- [ ] ")] {
            let edit = try XCTUnwrap(MarkdownSelectionEdit.make(command: command, text: "", selection: NSRange(location: 0, length: 0)))
            XCTAssertEqual(edit.replacement, prefix)
            XCTAssertEqual(edit.selectedRange, NSRange(location: prefix.utf16.count, length: 0))
        }
    }

    func testListToolbarPreservesCaretAndTogglesExistingList() throws {
        for (command, prefix) in [(MarkdownToolbarCommand.bullet, "- "), (.task, "- [ ] ")] {
            let first = try XCTUnwrap(MarkdownSelectionEdit.make(command: command, text: "hello", selection: NSRange(location: 3, length: 0)))
            XCTAssertEqual(first.replacement, prefix + "hello")
            XCTAssertEqual(first.selectedRange, NSRange(location: prefix.utf16.count + 3, length: 0))
            let second = try XCTUnwrap(MarkdownSelectionEdit.make(command: command, text: first.replacement, selection: first.selectedRange))
            XCTAssertEqual(second.replacement, "hello")
            XCTAssertEqual(second.selectedRange, NSRange(location: 3, length: 0))
        }
    }

    func testChangingBulletToTaskReplacesRatherThanStacksPrefixes() throws {
        let edit = try XCTUnwrap(MarkdownSelectionEdit.make(command: .task, text: "- hello", selection: NSRange(location: 7, length: 0)))
        XCTAssertEqual(edit.replacement, "- [ ] hello")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 11, length: 0))
    }

    func testPageSwitchResetsToolbarSelectionToIncomingPageSelection() {
        var state = EditorSelectionState(
            documentID: "first",
            selection: NSRange(location: 8, length: 2)
        )

        state.synchronize(
            documentID: "second",
            selection: NSRange(location: 1, length: 3)
        )

        XCTAssertEqual(state.documentID, "second")
        XCTAssertEqual(state.selection, NSRange(location: 1, length: 3))
    }

    func testSamePageRefreshDoesNotDiscardCurrentToolbarSelection() {
        var state = EditorSelectionState(
            documentID: "first",
            selection: NSRange(location: 8, length: 2)
        )

        state.synchronize(
            documentID: "first",
            selection: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(state.selection, NSRange(location: 8, length: 2))
    }

    @MainActor
    func testEditorAppearanceAppliesExactSurfaceToNativeTextAndScrollViews() throws {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        scrollView.documentView = textView

        MarkdownEditorAppearance.tuckNote().apply(to: textView)

        let expected = try XCTUnwrap(
            NSColor(TuckNoteTheme.editor).usingColorSpace(.sRGB)
        )
        XCTAssertEqual(
            textView.backgroundColor.usingColorSpace(.sRGB),
            expected
        )
        XCTAssertTrue(scrollView.drawsBackground)
        XCTAssertEqual(
            scrollView.backgroundColor.usingColorSpace(.sRGB),
            expected
        )
        XCTAssertEqual(
            MarkdownEditorAppearance.tuckNote().surface.usingColorSpace(.sRGB),
            expected
        )
        XCTAssertEqual(
            textView.textColor?.usingColorSpace(.sRGB),
            try XCTUnwrap(NSColor(TuckNoteTheme.ink).usingColorSpace(.sRGB))
        )
        XCTAssertEqual(
            textView.typingAttributes[.foregroundColor] as? NSColor,
            MarkdownEditorAppearance.tuckNote().ink
        )
    }

    @MainActor
    func testEditorAppearanceCarriesCodeBlockBackgroundFromPalette() throws {
        let palette = TuckNoteTheme.palette(for: .light)
        let appearance = MarkdownEditorAppearance.tuckNote(palette: palette)

        XCTAssertEqual(
            appearance.codeBlockBackground.usingColorSpace(.sRGB),
            try XCTUnwrap(NSColor(palette.codeBlockBackground).usingColorSpace(.sRGB))
        )
    }

    @MainActor
    func testEditorAppearanceCarriesDarkCodeBlockBackgroundFromPalette() throws {
        let palette = TuckNoteTheme.palette(for: .dark)
        let appearance = MarkdownEditorAppearance.tuckNote(palette: palette)

        XCTAssertEqual(
            appearance.codeBlockBackground.usingColorSpace(.sRGB),
            try XCTUnwrap(NSColor(palette.codeBlockBackground).usingColorSpace(.sRGB))
        )
        XCTAssertNotEqual(
            appearance.codeBlockBackground.usingColorSpace(.sRGB),
            try XCTUnwrap(NSColor(TuckNoteTheme.light.codeBlockBackground).usingColorSpace(.sRGB))
        )
    }

    @MainActor
    func testDarkCodeHighlighterSpecPinsDarkTheme() {
        let appearance = MarkdownEditorAppearance.tuckNote(palette: TuckNoteTheme.dark)

        let spec = MarkdownCodeHighlighterSpec.make(appearance: appearance, isDarkTheme: true)

        XCTAssertEqual(spec.theme, "atom-one-dark")
        XCTAssertEqual(spec.background, appearance.codeBlockBackground)
    }

    func testThemeChangesProduceDistinctEditorRenderIDs() {
        XCTAssertNotEqual(
            EditorRenderIdentity.make(documentID: "page", themeMode: .light),
            EditorRenderIdentity.make(documentID: "page", themeMode: .dark)
        )
    }

    @MainActor
    func testTaskCheckboxPolisherHidesMarkdownSyntaxAndKeepsCheckboxAttribute() {
        let textView = NSTextView()
        textView.string = "- [x] done"
        let storage = textView.textStorage!
        let appearance = MarkdownEditorAppearance.tuckNote()

        TuckNoteTaskCheckboxPolisher.apply(to: textView, appearance: appearance)

        let syntaxRange = NSRange(location: 0, length: 5)
        let checkboxRange = NSRange(location: 2, length: 3)
        let contentRange = NSRange(location: 6, length: 4)
        for location in syntaxRange.location..<NSMaxRange(syntaxRange) {
            XCTAssertEqual(storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor, .clear)
        }
        XCTAssertEqual(storage.attribute(.taskCheckbox, at: checkboxRange.location, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(storage.attribute(.foregroundColor, at: contentRange.location, effectiveRange: nil) as? NSColor, appearance.mutedInk)
        XCTAssertEqual(storage.attribute(.strikethroughColor, at: contentRange.location, effectiveRange: nil) as? NSColor, appearance.ink)
    }

    @MainActor
    func testTaskCheckboxPolisherAddsReadableSpacingBetweenTaskLines() {
        let textView = NSTextView()
        textView.string = "- [ ] one\n- [ ] two"
        let storage = textView.textStorage!

        TuckNoteTaskCheckboxPolisher.apply(to: textView, appearance: .tuckNote())

        let paragraphStyle = storage.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.paragraphSpacing, TuckNoteTheme.markdownTaskParagraphSpacing)
    }

    @MainActor
    func testTaskCheckboxPolisherCanHideCompletedTaskLines() {
        let textView = NSTextView()
        textView.string = "- [x] done\n- [ ] next"
        let storage = textView.textStorage!

        TuckNoteTaskCheckboxPolisher.apply(
            to: textView,
            appearance: .tuckNote(),
            hidesCompletedTasks: true
        )

        XCTAssertEqual(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .clear)
        let hiddenFont = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertLessThanOrEqual(hiddenFont?.pointSize ?? 99, 1)
        XCTAssertNotEqual(storage.attribute(.foregroundColor, at: 17, effectiveRange: nil) as? NSColor, .clear)
    }

    @MainActor
    func testTaskCheckboxPolisherRestoresCompletedLinesAfterShowingAgain() {
        let textView = NSTextView()
        textView.string = "- [x] done\n- [ ] next"
        let storage = textView.textStorage!

        TuckNoteTaskCheckboxPolisher.apply(
            to: textView,
            appearance: .tuckNote(),
            hidesCompletedTasks: true
        )
        TuckNoteTaskCheckboxPolisher.apply(
            to: textView,
            appearance: .tuckNote(),
            hidesCompletedTasks: false
        )

        let restoredFont = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertGreaterThan(restoredFont?.pointSize ?? 0, 1)
        XCTAssertNotEqual(storage.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? NSColor, .clear)
    }

    @MainActor
    func testTaskCheckboxIndicatorUsesAccentFillWhenChecked() {
        let appearance = MarkdownEditorAppearance.tuckNote(palette: TuckNoteTheme.dark)

        let style = TaskCheckboxIndicatorStyle.make(isChecked: true, appearance: appearance)

        XCTAssertEqual(style.fillColor, appearance.accent)
        XCTAssertEqual(style.borderColor, appearance.accent)
        XCTAssertNotEqual(style.fillColor, appearance.ink)
    }

    @MainActor
    func testUncheckedTaskCheckboxIndicatorCoversDefaultRenderer() {
        let appearance = MarkdownEditorAppearance.tuckNote(palette: TuckNoteTheme.light)

        let style = TaskCheckboxIndicatorStyle.make(isChecked: false, appearance: appearance)

        XCTAssertEqual(style.fillColor, appearance.surface)
        XCTAssertEqual(style.borderColor, appearance.mutedInk)
    }

    func testTaskToggleMarksCurrentUncheckedTaskComplete() throws {
        let edit = try XCTUnwrap(MarkdownTaskToggle.make(
            text: "alpha\n- [ ] study\nomega",
            selection: NSRange(location: 10, length: 0)
        ))

        XCTAssertEqual(edit.range, NSRange(location: 9, length: 1))
        XCTAssertEqual(edit.replacement, "x")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 10, length: 0))
    }

    func testTaskToggleClearsCurrentCheckedTask() throws {
        let edit = try XCTUnwrap(MarkdownTaskToggle.make(
            text: "- [x] study",
            selection: NSRange(location: 7, length: 0)
        ))

        XCTAssertEqual(edit.range, NSRange(location: 3, length: 1))
        XCTAssertEqual(edit.replacement, " ")
    }

    func testTaskCursorProtectionMovesInsertionOutOfCheckboxSyntax() {
        let protected = MarkdownTaskCursorProtection.protect(
            text: "- [ ] study",
            selection: NSRange(location: 3, length: 0)
        )

        XCTAssertEqual(protected, NSRange(location: 6, length: 0))
    }

    func testTaskCursorProtectionPreservesSelectionAcrossCheckboxSyntax() {
        let protected = MarkdownTaskCursorProtection.protect(
            text: "- [ ] study",
            selection: NSRange(location: 0, length: 5)
        )

        XCTAssertEqual(protected, NSRange(location: 0, length: 5))
    }

    func testTaskCursorProtectionMovesInsertionOutOfBulletMarker() {
        let protected = MarkdownTaskCursorProtection.protect(
            text: "- study",
            selection: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(protected, NSRange(location: 2, length: 0))
    }

    func testTaskCursorProtectionPreservesSelectionAcrossBulletMarker() {
        let protected = MarkdownTaskCursorProtection.protect(
            text: "- study",
            selection: NSRange(location: 0, length: 1)
        )

        XCTAssertEqual(protected, NSRange(location: 0, length: 1))
    }

    func testTaskCursorProtectionMovesInsertionOutOfNumberedMarker() {
        let protected = MarkdownTaskCursorProtection.protect(
            text: "1. study",
            selection: NSRange(location: 1, length: 0)
        )

        XCTAssertEqual(protected, NSRange(location: 3, length: 0))
    }

    func testTaskCursorProtectionLeavesTaskBodySelectionAlone() {
        let protected = MarkdownTaskCursorProtection.protect(
            text: "- [ ] study",
            selection: NSRange(location: 8, length: 0)
        )

        XCTAssertEqual(protected, NSRange(location: 8, length: 0))
    }

    func testTaskProgressCountsCompletedTasks() {
        let progress = MarkdownTaskProgress.make(
            from: """
            - [x] first
            - [ ] second
            paragraph
            1. [X] third
            """
        )

        XCTAssertEqual(progress.completed, 2)
        XCTAssertEqual(progress.total, 3)
        XCTAssertEqual(progress.summary, "2/3 done")
    }

    func testToolbarContainsExactlyTheEightFocusedCommands() {
        XCTAssertEqual(
            MarkdownToolbarCommand.allCases,
            [.bold, .italic, .link, .bullet, .numbered, .task, .quote, .inlineCode]
        )
        XCTAssertEqual(
            MarkdownToolbarCommand.allCases.map(\.title),
            ["Bold", "Italic", "Link", "Bullet", "Numbered", "Task", "Quote", "Inline Code"]
        )
    }

    func testInlineCommandsWrapSelectedText() throws {
        let source = "alpha beta"
        let selection = NSRange(location: 6, length: 4)

        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .link, text: source, selection: selection)).replacement,
            "[beta](url)"
        )
        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .inlineCode, text: source, selection: selection)).replacement,
            "`beta`"
        )
        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .bold, text: source, selection: selection)).replacement,
            "**beta**"
        )
        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .italic, text: source, selection: selection)).replacement,
            "*beta*"
        )
    }

    func testInlineCommandsWrapTaskTextWithoutTouchingCheckboxSyntax() throws {
        let source = "- [ ] study"
        let selection = NSRange(location: 6, length: 5)

        let edit = try XCTUnwrap(
            MarkdownSelectionEdit.make(command: .bold, text: source, selection: selection)
        )

        XCTAssertEqual(edit.range, selection)
        XCTAssertEqual(edit.replacement, "**study**")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 8, length: 5))
    }

    func testInlineCommandsInsertEditableMarkersAtEmptySelection() throws {
        let selection = NSRange(location: 5, length: 0)

        let link = try XCTUnwrap(
            MarkdownSelectionEdit.make(command: .link, text: "alpha", selection: selection)
        )
        XCTAssertEqual(link.replacement, "[](url)")
        XCTAssertEqual(link.selectedRange, NSRange(location: 6, length: 0))

        let code = try XCTUnwrap(
            MarkdownSelectionEdit.make(command: .inlineCode, text: "alpha", selection: selection)
        )
        XCTAssertEqual(code.replacement, "``")
        XCTAssertEqual(code.selectedRange, NSRange(location: 6, length: 0))

        let bold = try XCTUnwrap(
            MarkdownSelectionEdit.make(command: .bold, text: "alpha", selection: selection)
        )
        XCTAssertEqual(bold.replacement, "****")
        XCTAssertEqual(bold.selectedRange, NSRange(location: 7, length: 0))
    }

    func testBlockCommandsPrefixEverySelectedLine() throws {
        let source = "one\ntwo\nthree"
        let selection = NSRange(location: 0, length: 7)

        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .bullet, text: source, selection: selection)).replacement,
            "- one\n- two"
        )
        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .numbered, text: source, selection: selection)).replacement,
            "1. one\n1. two"
        )
        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .task, text: source, selection: selection)).replacement,
            "- [ ] one\n- [ ] two"
        )
        XCTAssertEqual(
            try XCTUnwrap(MarkdownSelectionEdit.make(command: .quote, text: source, selection: selection)).replacement,
            "> one\n> two"
        )
    }

    func testBlockCommandPrefixesCurrentLineForEmptySelection() throws {
        let edit = try XCTUnwrap(
            MarkdownSelectionEdit.make(
                command: .task,
                text: "one\ntwo",
                selection: NSRange(location: 5, length: 0)
            )
        )

        XCTAssertEqual(edit.range, NSRange(location: 4, length: 3))
        XCTAssertEqual(edit.replacement, "- [ ] two")
    }

    func testInvalidSelectionProducesNoEdit() {
        XCTAssertNil(
            MarkdownSelectionEdit.make(
                command: .inlineCode,
                text: "short",
                selection: NSRange(location: 10, length: 1)
            )
        )
    }

    func testImagePasteReturnsSavedReference() throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let sourceImage = NSImage(size: NSSize(width: 2, height: 2))
        var savedImage: NSImage?
        var error: Error?

        let reference = MarkdownImagePaste.reference(
            from: pasteboard,
            loadImage: { suppliedPasteboard in
                XCTAssertTrue(suppliedPasteboard === pasteboard)
                return sourceImage
            },
            save: {
                savedImage = $0
                return "![[saved.png]]"
            },
            onError: { error = $0 }
        )

        XCTAssertEqual(reference, "![[saved.png]]")
        XCTAssertNotNil(savedImage)
        XCTAssertNil(error)
    }

    func testImagePasteFailureReturnsNilAndReportsError() {
        struct WriteFailure: Error, Equatable {}
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let sourceImage = NSImage(size: NSSize(width: 2, height: 2))
        var reportedError: Error?

        let reference = MarkdownImagePaste.reference(
            from: pasteboard,
            loadImage: { suppliedPasteboard in
                XCTAssertTrue(suppliedPasteboard === pasteboard)
                return sourceImage
            },
            save: { _ in throw WriteFailure() },
            onError: { reportedError = $0 }
        )

        XCTAssertNil(reference)
        XCTAssertTrue(reportedError is WriteFailure)
    }

    func testNonImagePasteFallsThroughWithoutReportingError() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("plain text", forType: .string)
        var didSave = false
        var reportedError: Error?

        let reference = MarkdownImagePaste.reference(
            from: pasteboard,
            save: { _ in
                didSave = true
                return "![[unexpected.png]]"
            },
            onError: { reportedError = $0 }
        )

        XCTAssertNil(reference)
        XCTAssertFalse(didSave)
        XCTAssertNil(reportedError)
    }

    func testImageFileDropReturnsSavedReference() throws {
        let imageURL = URL(fileURLWithPath: "/tmp/dropped.png")
        let sourceImage = NSImage(size: NSSize(width: 2, height: 2))
        var loadedURL: URL?
        var savedImage: NSImage?

        let reference = MarkdownImageDrop.reference(
            from: [imageURL],
            loadImage: { url in
                loadedURL = url
                return sourceImage
            },
            save: {
                savedImage = $0
                return "![[dropped.png]]"
            },
            onError: { _ in XCTFail("Unexpected drop error") }
        )

        XCTAssertEqual(reference, "![[dropped.png]]")
        XCTAssertEqual(loadedURL, imageURL)
        XCTAssertNotNil(savedImage)
    }

    func testNonImageFileDropFallsThrough() {
        let textURL = URL(fileURLWithPath: "/tmp/notes.txt")
        var didLoad = false
        var didSave = false

        let reference = MarkdownImageDrop.reference(
            from: [textURL],
            loadImage: { _ in
                didLoad = true
                return NSImage(size: NSSize(width: 2, height: 2))
            },
            save: { _ in
                didSave = true
                return "![[unexpected.png]]"
            },
            onError: { _ in XCTFail("Unexpected drop error") }
        )

        XCTAssertNil(reference)
        XCTAssertFalse(didLoad)
        XCTAssertFalse(didSave)
    }

    func testImageDropCreatesStandaloneBlockAtDropLocation() throws {
        let edit = try XCTUnwrap(MarkdownImageDropEdit.make(
            reference: "![[dropped.png]]",
            text: "beforeafter",
            insertionLocation: 6
        ))

        XCTAssertEqual(edit.range, NSRange(location: 6, length: 0))
        XCTAssertEqual(edit.replacement, "\n![[dropped.png]]\n")
        XCTAssertEqual(edit.selectedRange, NSRange(location: 24, length: 0))
    }

    func testImageDropTreatsCarriageReturnAsBlockBoundary() throws {
        let edit = try XCTUnwrap(MarkdownImageDropEdit.make(
            reference: "![[dropped.png]]",
            text: "before\rafter",
            insertionLocation: 7
        ))

        XCTAssertEqual(edit.replacement, "![[dropped.png]]\n")
    }

    @MainActor
    func testSelectionCoordinatorObservesAndRestoresOnlyItsAssociatedEditor() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let root = NSView(frame: window.contentView!.bounds)
        let firstGroup = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 300))
        let secondGroup = NSView(frame: NSRect(x: 250, y: 0, width: 250, height: 300))
        let monitor = SelectionMonitorView()
        let firstEditor = NSTextView(frame: firstGroup.bounds)
        let secondEditor = NSTextView(frame: secondGroup.bounds)
        firstEditor.string = "first editor"
        secondEditor.string = "second editor"
        let secondSelectionBeforeRestore = secondEditor.selectedRange()
        firstGroup.addSubview(firstEditor)
        firstGroup.addSubview(monitor)
        secondGroup.addSubview(secondEditor)
        root.addSubview(firstGroup)
        root.addSubview(secondGroup)
        window.contentView = root
        var observed: [NSRange] = []
        let coordinator = TextSelectionCoordinator { observed.append($0) }

        coordinator.attach(
            to: monitor,
            documentID: "first",
            initialSelection: NSRange(location: 2, length: 3),
            requestedSelection: nil,
            schedule: false
        )
        coordinator.resolveAssociationAndApplySelection()

        XCTAssertTrue(coordinator.textView === firstEditor)
        XCTAssertEqual(firstEditor.selectedRange(), NSRange(location: 2, length: 3))
        XCTAssertEqual(secondEditor.selectedRange(), secondSelectionBeforeRestore)
        XCTAssertTrue(observed.isEmpty, "restoration must not be persisted as a user selection")

        secondEditor.setSelectedRange(NSRange(location: 4, length: 1))
        NotificationCenter.default.post(
            name: NSTextView.didChangeSelectionNotification,
            object: secondEditor
        )
        XCTAssertTrue(observed.isEmpty)

        firstEditor.setSelectedRange(NSRange(location: 6, length: 2))
        NotificationCenter.default.post(
            name: NSTextView.didChangeSelectionNotification,
            object: firstEditor
        )
        XCTAssertEqual(observed.last, NSRange(location: 6, length: 2))
        coordinator.stopObserving()
    }

    @MainActor
    func testSelectionCoordinatorAppliesPromisedRangesAfterEveryHostTransformation() throws {
        let commands: [(MarkdownToolbarCommand, String, NSRange)] = [
            (.link, "alpha", NSRange(location: 5, length: 0)),
            (.inlineCode, "alpha", NSRange(location: 5, length: 0)),
            (.link, "alpha beta", NSRange(location: 6, length: 4)),
            (.inlineCode, "alpha beta", NSRange(location: 6, length: 4)),
            (.task, "one\ntwo", NSRange(location: 0, length: 7))
        ]

        for (command, source, originalSelection) in commands {
            let edit = try XCTUnwrap(
                MarkdownSelectionEdit.make(
                    command: command,
                    text: source,
                    selection: originalSelection
                )
            )
            let editor = NSTextView()
            editor.string = (source as NSString).replacingCharacters(
                in: edit.range,
                with: edit.replacement
            )
            let group = NSView()
            let monitor = SelectionMonitorView()
            group.addSubview(editor)
            group.addSubview(monitor)
            let coordinator = TextSelectionCoordinator { _ in }
            let request = EditorSelectionRequest(documentID: "document", range: edit.selectedRange)

            coordinator.attach(
                to: monitor,
                documentID: "document",
                initialSelection: originalSelection,
                requestedSelection: request,
                schedule: false
            )
            coordinator.resolveAssociationAndApplySelection()

            XCTAssertEqual(editor.selectedRange(), edit.selectedRange, command.title)
            XCTAssertEqual(coordinator.lastAppliedRequestID, request.id, command.title)
            coordinator.stopObserving()
        }
    }

    @MainActor
    func testSelectionCoordinatorIgnoresRequestFromOutgoingDocument() {
        let editor = NSTextView()
        editor.string = "new page"
        let group = NSView()
        let monitor = SelectionMonitorView()
        group.addSubview(editor)
        group.addSubview(monitor)
        let coordinator = TextSelectionCoordinator { _ in }
        let staleRequest = EditorSelectionRequest(
            documentID: "old-page",
            range: NSRange(location: 7, length: 1)
        )

        coordinator.attach(
            to: monitor,
            documentID: "new-page",
            initialSelection: NSRange(location: 1, length: 2),
            requestedSelection: staleRequest,
            schedule: false
        )
        coordinator.resolveAssociationAndApplySelection()

        XCTAssertEqual(editor.selectedRange(), NSRange(location: 1, length: 2))
        XCTAssertNil(coordinator.lastAppliedRequestID)
        coordinator.stopObserving()
    }

}
