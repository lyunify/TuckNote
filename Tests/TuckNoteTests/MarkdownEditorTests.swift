import AppKit
import XCTest
@testable import TuckNote

final class MarkdownEditorTests: XCTestCase {
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

}
