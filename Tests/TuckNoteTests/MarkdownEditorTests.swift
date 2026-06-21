import AppKit
import XCTest
@testable import TuckNote

final class MarkdownEditorTests: XCTestCase {
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

        MarkdownEditorAppearance.tuckNote.apply(to: textView)

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
            MarkdownEditorAppearance.tuckNote.surface.usingColorSpace(.sRGB),
            expected
        )
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
