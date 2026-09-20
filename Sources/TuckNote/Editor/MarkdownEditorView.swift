import AppKit
import MarkdownEngine
import MarkdownEngineCodeBlocks
import SwiftUI
import UniformTypeIdentifiers

enum MarkdownToolbarCommand: String, CaseIterable, Identifiable {
    case bold
    case italic
    case link
    case bullet
    case numbered
    case task
    case quote
    case inlineCode

    var id: Self { self }

    var title: String {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .link: "Link"
        case .bullet: "Bullet"
        case .numbered: "Numbered"
        case .task: "Task"
        case .quote: "Quote"
        case .inlineCode: "Inline Code"
        }
    }

    var symbol: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .link: "link"
        case .bullet: "list.bullet"
        case .numbered: "list.number"
        case .task: "checklist"
        case .quote: "text.quote"
        case .inlineCode: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct MarkdownSelectionEdit: Equatable {
    let range: NSRange
    let replacement: String
    let selectedRange: NSRange

    static func make(
        command: MarkdownToolbarCommand,
        text: String,
        selection: NSRange
    ) -> MarkdownSelectionEdit? {
        let nsText = text as NSString
        guard selection.location != NSNotFound,
              selection.location >= 0,
              selection.length >= 0,
              NSMaxRange(selection) <= nsText.length else {
            return nil
        }

        switch command {
        case .bold:
            return emphasisEdit(text: nsText, selection: selection, width: 2)
        case .italic:
            return emphasisEdit(text: nsText, selection: selection, width: 1)
        case .link:
            return inlineEdit(
                selection: selection,
                selectedText: nsText.substring(with: selection),
                prefix: "[",
                suffix: "](url)"
            )
        case .inlineCode:
            return inlineEdit(
                selection: selection,
                selectedText: nsText.substring(with: selection),
                prefix: "`",
                suffix: "`"
            )
        case .bullet:
            return listEdit(command: command, prefix: "- ", text: nsText, selection: selection)
        case .numbered:
            return listEdit(command: command, prefix: "1. ", text: nsText, selection: selection)
        case .task:
            return listEdit(command: command, prefix: "- [ ] ", text: nsText, selection: selection)
        case .quote:
            return blockEdit(prefix: "> ", text: nsText, selection: selection)
        }
    }

    private static func emphasisEdit(text: NSString, selection: NSRange, width: Int) -> Self {
        var content = selection
        if content.length > 0 {
            let line = text.lineRange(for: NSRange(location: content.location, length: 0))
            if content.location == line.location,
               let prefix = MarkdownListPrefix.parse(text.substring(with: line)) {
                let skipped = min(prefix.length, content.length)
                content.location += skipped
                content.length -= skipped
            }
            let trimmed = text.substring(with: content).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                content = text.range(of: trimmed, options: .literal, range: content)
            } else {
                return Self(range: selection, replacement: text.substring(with: selection), selectedRange: selection)
            }
        }

        let marker = String(repeating: "*", count: width)
        // An empty pair has no parsed emphasis yet, but pressing the same button must undo it.
        if content.length == 0, content.location >= width, content.location + width <= text.length,
           text.substring(with: NSRange(location: content.location - width, length: width * 2)) == marker + marker {
            return Self(range: NSRange(location: content.location - width, length: width * 2), replacement: "",
                        selectedRange: NSRange(location: content.location - width, length: 0))
        }
        if let removal = MarkdownEmphasis(text as String).removingStyle(in: text, selection: content, width: width) {
            return removal
        }
        return inlineEdit(selection: content, selectedText: text.substring(with: content), prefix: marker, suffix: marker)
    }

    @MainActor
    static func apply(_ command: MarkdownToolbarCommand, to editor: NSTextView) -> Bool {
        guard editor.isEditable, !editor.hasMarkedText(),
              editor.delegate is NativeTextViewCoordinator,
              let edit = make(command: command, text: editor.string, selection: editor.selectedRange()) else { return false }
        editor.breakUndoCoalescing()
        editor.insertText(edit.replacement, replacementRange: edit.range)
        editor.setSelectedRange(edit.selectedRange)
        editor.undoManager?.setActionName(command.title)
        editor.breakUndoCoalescing()
        return true
    }

    private static func inlineEdit(
        selection: NSRange,
        selectedText: String,
        prefix: String,
        suffix: String
    ) -> MarkdownSelectionEdit {
        let replacement = prefix + selectedText + suffix
        let selectedRange = NSRange(
            location: selection.location + (prefix as NSString).length,
            length: (selectedText as NSString).length
        )
        return MarkdownSelectionEdit(
            range: selection,
            replacement: replacement,
            selectedRange: selectedRange
        )
    }

    private static func blockEdit(
        prefix: String,
        text: NSString,
        selection: NSRange
    ) -> MarkdownSelectionEdit {
        let endLocation = selection.length == 0
            ? selection.location
            : max(selection.location, NSMaxRange(selection) - 1)
        let startLine = text.lineRange(for: NSRange(location: selection.location, length: 0))
        let endLine = text.lineRange(for: NSRange(location: endLocation, length: 0))
        var range = NSRange(
            location: startLine.location,
            length: NSMaxRange(endLine) - startLine.location
        )
        while range.length > 0 {
            let finalCharacter = text.substring(with: NSRange(location: NSMaxRange(range) - 1, length: 1))
            guard finalCharacter == "\n" || finalCharacter == "\r" else { break }
            range.length -= 1
        }

        let original = text.substring(with: range)
        let replacement = original
            .components(separatedBy: "\n")
            .map { prefix + $0 }
            .joined(separator: "\n")
        return MarkdownSelectionEdit(
            range: range,
            replacement: replacement,
            selectedRange: NSRange(location: range.location, length: (replacement as NSString).length)
        )
    }

    private static func listEdit(command: MarkdownToolbarCommand, prefix: String, text: NSString, selection: NSRange) -> Self {
        let last = selection.length == 0 ? selection.location : NSMaxRange(selection) - 1
        var range = NSUnionRange(text.lineRange(for: NSRange(location: selection.location, length: 0)),
                                 text.lineRange(for: NSRange(location: last, length: 0)))
        while range.length > 0, [10, 13].contains(text.character(at: NSMaxRange(range) - 1)) { range.length -= 1 }
        let lines = text.substring(with: range).components(separatedBy: "\n")
        let prefixes = lines.map { MarkdownListPrefix.parse($0) }
        let remove = prefixes.allSatisfy { $0?.command == command }
        var edits: [(range: NSRange, replacement: String)] = []
        var offset = range.location
        for (line, existing) in zip(lines, prefixes) {
            let indent = existing?.indent ?? String(line.prefix { $0 == " " || $0 == "\t" })
            let length = existing?.length ?? indent.utf16.count
            edits.append((NSRange(location: offset, length: length), indent + (remove ? "" : prefix)))
            offset += line.utf16.count + 1
        }
        func mapped(_ position: Int) -> Int {
            var delta = 0
            for edit in edits {
                guard position >= edit.range.location else { break }
                if position <= NSMaxRange(edit.range) {
                    return edit.range.location + delta + edit.replacement.utf16.count
                }
                delta += edit.replacement.utf16.count - edit.range.length
            }
            return position + delta
        }
        let replacement = NSMutableString(string: text.substring(with: range))
        for edit in edits.reversed() {
            replacement.replaceCharacters(in: NSRange(location: edit.range.location - range.location, length: edit.range.length), with: edit.replacement)
        }
        let start = mapped(selection.location)
        return Self(range: range, replacement: replacement as String,
                    selectedRange: NSRange(location: start, length: max(0, mapped(NSMaxRange(selection)) - start)))
    }
}

struct MarkdownListPrefix {
    let indent: String
    let length: Int
    let command: MarkdownToolbarCommand
    private static let pattern = try! NSRegularExpression(pattern: #"^([ \t]*)([-+*•]|\d+\.)[ \t]+(\[[ xX]\][ \t]*)?"#)

    static func parse(_ line: String) -> Self? {
        let text = line as NSString
        guard let match = pattern.firstMatch(in: line, range: NSRange(location: 0, length: text.length)) else { return nil }
        let marker = text.substring(with: match.range(at: 2))
        return Self(indent: text.substring(with: match.range(at: 1)), length: match.range.length,
                    command: match.range(at: 3).location != NSNotFound ? .task : (marker.hasSuffix(".") ? .numbered : .bullet))
    }

    @MainActor
    static func deleteBackward(in editor: NSTextView) -> Bool {
        let selection = editor.selectedRange()
        guard editor.isEditable, !editor.hasMarkedText(), selection.length == 0 else { return false }
        let text = editor.string as NSString
        guard selection.location <= text.length else { return false }
        let lineRange = text.lineRange(for: selection)
        guard let prefix = parse(text.substring(with: lineRange)),
              selection.location == lineRange.location + prefix.length,
              !isInsideCodeFence(text.substring(to: lineRange.location)) else { return false }
        let range = NSRange(location: lineRange.location, length: prefix.length)
        editor.insertText("", replacementRange: range)
        editor.setSelectedRange(NSRange(location: range.location, length: 0))
        return true
    }

    private static func isInsideCodeFence(_ precedingText: String) -> Bool {
        var openFence: (marker: Character, count: Int)?
        for line in precedingText.components(separatedBy: .newlines) {
            let indent = line.prefix { $0 == " " }
            guard indent.count <= 3 else { continue }
            let content = line.dropFirst(indent.count)
            guard let marker = content.first, marker == "`" || marker == "~" else { continue }
            let count = content.prefix { $0 == marker }.count
            guard count >= 3 else { continue }
            let suffix = content.dropFirst(count)
            if let fence = openFence {
                if marker == fence.marker, count >= fence.count,
                   suffix.allSatisfy({ $0 == " " || $0 == "\t" }) {
                    openFence = nil
                }
            } else if marker != "`" || !suffix.contains("`") {
                openFence = (marker, count)
            }
        }
        return openFence != nil
    }
}

struct MarkdownTaskToggleEdit: Equatable {
    let range: NSRange
    let replacement: String
    let selectedRange: NSRange
}

enum MarkdownTaskToggle {
    private static let taskPattern = try! NSRegularExpression(
        pattern: #"^([ \t]*(?:[-•*+]|\d+\.)(?:[ \t]+)\[)([ xX])(\])"#,
        options: []
    )

    static func make(text: String, selection: NSRange) -> MarkdownTaskToggleEdit? {
        let nsText = text as NSString
        guard selection.location != NSNotFound,
              selection.location >= 0,
              selection.location <= nsText.length else {
            return nil
        }

        let lineRange = nsText.lineRange(for: NSRange(location: selection.location, length: 0))
        let line = nsText.substring(with: lineRange) as NSString
        guard let match = taskPattern.firstMatch(
            in: line as String,
            range: NSRange(location: 0, length: line.length)
        ) else {
            return nil
        }

        let checkboxStateRange = match.range(at: 2)
        let absoluteRange = NSRange(
            location: lineRange.location + checkboxStateRange.location,
            length: checkboxStateRange.length
        )
        let checkboxState = line.substring(with: checkboxStateRange)
        return MarkdownTaskToggleEdit(
            range: absoluteRange,
            replacement: checkboxState == " " ? "x" : " ",
            selectedRange: selection
        )
    }
}

enum MarkdownTaskCursorProtection {
    private static let taskPrefixPattern = try! NSRegularExpression(
        pattern: #"^[ \t]*(?:(?:[-•*+]|\d+\.)(?:[ \t]+)\[[ xX]\][ \t]*|(?:[-•*+]|\d+\.)(?:[ \t]+))"#,
        options: []
    )

    static func protect(text: String, selection: NSRange) -> NSRange {
        guard selection.location != NSNotFound,
              selection.length == 0 else {
            return selection
        }
        let nsText = text as NSString
        guard selection.location >= 0,
              selection.location <= nsText.length else {
            return selection
        }

        let lineRange = nsText.lineRange(for: NSRange(location: selection.location, length: 0))
        let line = nsText.substring(with: lineRange) as NSString
        guard let match = taskPrefixPattern.firstMatch(
            in: line as String,
            range: NSRange(location: 0, length: line.length)
        ) else {
            return selection
        }

        let protectedRange = NSRange(
            location: lineRange.location,
            length: match.range.length
        )
        guard NSLocationInRange(selection.location, protectedRange) else { return selection }
        return NSRange(location: NSMaxRange(protectedRange), length: 0)
    }
}

struct MarkdownTaskProgress: Equatable {
    let completed: Int
    let total: Int

    var summary: String {
        "\(completed)/\(total) done"
    }

    static func make(from text: String) -> Self {
        let pattern = try! NSRegularExpression(
            pattern: #"^[ \t]*(?:[-•*+]|\d+\.)(?:[ \t]+)\[([ xX])\](?=[ \t]|$)"#,
            options: [.anchorsMatchLines]
        )
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var completed = 0
        var total = 0
        pattern.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else { return }
            total += 1
            let state = nsText.substring(with: match.range(at: 1))
            if state.localizedCaseInsensitiveContains("x") {
                completed += 1
            }
        }
        return Self(completed: completed, total: total)
    }
}

struct MarkdownCodeHighlighterSpec: Equatable {
    let theme: String
    let background: NSColor

    static func make(appearance: MarkdownEditorAppearance, isDarkTheme: Bool) -> Self {
        Self(
            theme: isDarkTheme ? "atom-one-dark" : "atom-one-light",
            background: appearance.codeBlockBackground
        )
    }
}

enum MarkdownImagePaste {
    static func reference(
        from pasteboard: NSPasteboard,
        loadImage: (NSPasteboard) -> NSImage? = image,
        save: (NSImage) throws -> String,
        onError: (Error) -> Void
    ) -> String? {
        guard let image = loadImage(pasteboard) else { return nil }
        do {
            return try save(image)
        } catch {
            onError(error)
            return nil
        }
    }

    private static func image(from pasteboard: NSPasteboard) -> NSImage? {
        guard let data = PasteboardImageReader.imageData(from: pasteboard) else { return nil }
        return NSImage(data: data)
    }
}

enum MarkdownImageDrop {
    static func reference(
        from urls: [URL],
        loadImage: (URL) -> NSImage? = { NSImage(contentsOf: $0) },
        save: (NSImage) throws -> String,
        onError: (Error) -> Void
    ) -> String? {
        guard let url = urls.first(where: isImageFile),
              let image = loadImage(url) else {
            return nil
        }
        do {
            return try save(image)
        } catch {
            onError(error)
            return nil
        }
    }

    private static func isImageFile(_ url: URL) -> Bool {
        guard url.isFileURL,
              let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }
}

struct MarkdownImageDropEdit: Equatable {
    let range: NSRange
    let replacement: String
    let selectedRange: NSRange

    static func make(
        reference: String,
        text: String,
        insertionLocation: Int
    ) -> Self? {
        let nsText = text as NSString
        guard insertionLocation >= 0, insertionLocation <= nsText.length else { return nil }

        let prefix = insertionLocation > 0
            && !isLineBreak(nsText.character(at: insertionLocation - 1)) ? "\n" : ""
        let suffix = insertionLocation < nsText.length
            && !isLineBreak(nsText.character(at: insertionLocation)) ? "\n" : ""
        let replacement = prefix + reference + suffix
        return Self(
            range: NSRange(location: insertionLocation, length: 0),
            replacement: replacement,
            selectedRange: NSRange(
                location: insertionLocation + (replacement as NSString).length,
                length: 0
            )
        )
    }

    private static func isLineBreak(_ character: unichar) -> Bool {
        character == 0x0A || character == 0x0D
    }
}

@MainActor
struct MarkdownEditorAppearance {
    let surface: NSColor
    let ink: NSColor
    let mutedInk: NSColor
    let accent: NSColor
    let separator: NSColor
    let codeBlockBackground: NSColor

    static func tuckNote(palette: TuckNotePalette = TuckNoteTheme.light) -> Self {
        Self(
            surface: NSColor(palette.editor),
            ink: NSColor(palette.ink),
            mutedInk: NSColor(palette.mutedInk),
            accent: NSColor(palette.accent),
            separator: NSColor(palette.border),
            codeBlockBackground: NSColor(palette.codeBlockBackground)
        )
    }

    func apply(to textView: NSTextView) {
        textView.drawsBackground = true
        textView.backgroundColor = surface
        // Setting textColor on a populated view repaints hidden Markdown markers.
        if textView.string.isEmpty { textView.textColor = ink }
        textView.insertionPointColor = ink
        textView.typingAttributes[.foregroundColor] = ink
        guard let scrollView = textView.enclosingScrollView else { return }
        scrollView.drawsBackground = true
        scrollView.backgroundColor = surface
    }
}

enum EditorRenderIdentity {
    static func make(documentID: String, themeMode: ThemeMode) -> String {
        "\(documentID)-\(themeMode.rawValue)"
    }
}

@MainActor
enum TuckNoteTaskCheckboxPolisher {
    private static let visibleFont = NSAttributedString.Key("TuckNotesVisibleTaskFont")
    private static let visibleParagraph = NSAttributedString.Key("TuckNotesVisibleTaskParagraph")
    private static let taskPattern = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-•*+]|\d+\.)([ \t]+)(\[[ xX]\])(?=[ \t]|$)"#,
        options: [.anchorsMatchLines]
    )

    static func apply(
        to textView: NSTextView,
        appearance: MarkdownEditorAppearance = .tuckNote(),
        hidesCompletedTasks: Bool = false
    ) {
        guard !textView.hasMarkedText(), let storage = textView.textStorage else { return }
        storage.beginEditing()
        defer { storage.endEditing() }
        let text = storage.string as NSString
        let fullRange = NSRange(location: 0, length: text.length)
        taskPattern.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match,
                  match.range(at: 2).location != NSNotFound,
                  match.range(at: 4).location != NSNotFound else { return }
            let markerRange = match.range(at: 2)
            let checkboxRange = match.range(at: 4)
            let syntaxRange = NSRange(
                location: markerRange.location,
                length: NSMaxRange(checkboxRange) - markerRange.location
            )
            let checkboxText = text.substring(with: checkboxRange)
            let isChecked = checkboxText.localizedCaseInsensitiveContains("x")
            var contentStart = NSMaxRange(checkboxRange)
            let lineRange = text.lineRange(for: match.range)
            while contentStart < NSMaxRange(lineRange),
                  isHorizontalWhitespace(text.character(at: contentStart)) {
                contentStart += 1
            }
            let contentRange = NSRange(
                location: contentStart,
                length: max(0, NSMaxRange(lineRange) - contentStart)
            )
            restoreCompletedTaskLineAttributes(in: storage, range: lineRange)

            if isChecked, hidesCompletedTasks {
                let paragraph = storage.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: nil) as? NSParagraphStyle
                    ?? visibleTaskParagraphStyle
                storage.addAttribute(visibleParagraph, value: paragraph, range: lineRange)
                storage.enumerateAttribute(.font, in: lineRange) { value, range, _ in
                    storage.addAttribute(visibleFont, value: value as? NSFont ?? NSFont.systemFont(ofSize: 14), range: range)
                }
                storage.addAttributes(hiddenCompletedTaskAttributes, range: lineRange)
                storage.addAttribute(.taskCheckbox, value: isChecked, range: checkboxRange)
                return
            }

            // Keep the engine's hanging indent and line metrics, including during IME restyles.
            if storage.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: nil) == nil {
                storage.addAttribute(.paragraphStyle, value: visibleTaskParagraphStyle, range: lineRange)
            }
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: syntaxRange)
            storage.addAttribute(.taskCheckbox, value: isChecked, range: checkboxRange)
            guard contentRange.length > 0 else { return }
            storage.addAttribute(.foregroundColor, value: isChecked ? appearance.mutedInk : appearance.ink, range: contentRange)
            if isChecked {
                storage.addAttribute(.strikethroughColor, value: appearance.ink, range: contentRange)
            }
        }
    }

    private static func isHorizontalWhitespace(_ character: unichar) -> Bool {
        character == 0x20 || character == 0x09
    }

    private static func restoreCompletedTaskLineAttributes(
        in storage: NSTextStorage,
        range: NSRange
    ) {
        storage.enumerateAttribute(visibleParagraph, in: range) { value, paragraphRange, _ in
            guard let paragraph = value as? NSParagraphStyle else { return }
            storage.addAttribute(.paragraphStyle, value: paragraph, range: paragraphRange)
        }
        storage.removeAttribute(visibleParagraph, range: range)
        storage.removeAttribute(.strikethroughColor, range: range)
        storage.enumerateAttribute(visibleFont, in: range) { value, fontRange, _ in
            guard let font = value as? NSFont else { return }
            storage.addAttribute(.font, value: font, range: fontRange)
        }
        storage.removeAttribute(visibleFont, range: range)
    }

    private static var visibleTaskParagraphStyle: NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = TuckNoteTheme.markdownTaskParagraphSpacing
        return paragraph
    }

    private static var hiddenCompletedTaskAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 0
        paragraph.maximumLineHeight = 0.1
        paragraph.lineSpacing = 0
        return [
            .font: NSFont.systemFont(ofSize: 0.1),
            .foregroundColor: NSColor.clear,
            .strikethroughColor: NSColor.clear,
            .paragraphStyle: paragraph
        ]
    }
}

struct TaskCheckboxIndicatorStyle: Equatable {
    let fillColor: NSColor
    let borderColor: NSColor
    let checkmarkColor: NSColor

    static func make(isChecked: Bool, appearance: MarkdownEditorAppearance) -> Self {
        if isChecked {
            return Self(
                fillColor: appearance.accent,
                borderColor: appearance.accent,
                checkmarkColor: .white
            )
        }
        return Self(
            fillColor: appearance.surface,
            borderColor: appearance.mutedInk,
            checkmarkColor: .clear
        )
    }
}

@MainActor
final class TaskCheckboxOverlayView: NSView {
    weak var textView: NSTextView?
    var hidesCompletedTasks = false {
        didSet { needsDisplay = true }
    }
    var editorAppearance: MarkdownEditorAppearance = .tuckNote() {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let textView,
              let storage = textView.textStorage,
              let window = textView.window else {
            return
        }

        let fullRange = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.taskCheckbox, in: fullRange, options: []) { value, range, _ in
            guard let isChecked = value as? Bool else { return }
            guard !(isChecked && hidesCompletedTasks) else { return }
            let screenRect = textView.firstRect(forCharacterRange: range, actualRange: nil)
            guard screenRect.width.isFinite,
                  screenRect.height.isFinite,
                  !screenRect.isEmpty else {
                return
            }

            let windowRect = window.convertFromScreen(screenRect)
            let localRect = convert(windowRect, from: nil)
            let size = min(15, max(11, localRect.height - 1))
            let boxRect = NSRect(
                x: localRect.minX - 2,
                y: localRect.midY - size / 2,
                width: size,
                height: size
            )
            drawCheckbox(in: boxRect, isChecked: isChecked)
        }
    }

    private func drawCheckbox(in rect: NSRect, isChecked: Bool) {
        let style = TaskCheckboxIndicatorStyle.make(isChecked: isChecked, appearance: editorAppearance)
        editorAppearance.surface.setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: -2, dy: -2), xRadius: 4, yRadius: 4).fill()

        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        style.fillColor.setFill()
        path.fill()
        style.borderColor.setStroke()
        path.lineWidth = 1.4
        path.stroke()

        guard isChecked else { return }
        let check = NSBezierPath()
        check.move(to: NSPoint(x: rect.minX + rect.width * 0.25, y: rect.midY))
        check.line(to: NSPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.30))
        check.line(to: NSPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.72))
        style.checkmarkColor.setStroke()
        check.lineWidth = 1.8
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()
    }
}

struct MarkdownEditorView: View {
    @Binding private var text: String
    let documentID: String
    let imageStore: ImageStore
    let palette: TuckNotePalette
    let initialSelection: NSRange
    let onSelectionChange: (NSRange) -> Void
    let onImagePasteError: () -> Void

    @State private var selectionState: EditorSelectionState
    @State private var editorTarget = MarkdownEditorTarget()
    @State private var hidesCompletedTasks = false

    init(
        text: Binding<String>,
        documentID: String,
        imageStore: ImageStore,
        palette: TuckNotePalette = TuckNoteTheme.light,
        initialSelection: NSRange = .init(location: 0, length: 0),
        onSelectionChange: @escaping (NSRange) -> Void,
        onImagePasteError: @escaping () -> Void = {}
    ) {
        _text = text
        self.documentID = documentID
        self.imageStore = imageStore
        self.palette = palette
        self.initialSelection = initialSelection
        self.onSelectionChange = onSelectionChange
        self.onImagePasteError = onImagePasteError
        let initialRenderID = EditorRenderIdentity.make(
            documentID: documentID,
            themeMode: palette.preferredColorScheme == .dark ? .dark : .light
        )
        _selectionState = State(initialValue: EditorSelectionState(
            documentID: initialRenderID,
            selection: initialSelection
        ))
    }

    private var appearance: MarkdownEditorAppearance {
        MarkdownEditorAppearance.tuckNote(palette: palette)
    }

    private var editorRenderID: String {
        let identity = EditorRenderIdentity.make(
            documentID: documentID,
            themeMode: palette.preferredColorScheme == .dark ? .dark : .light
        )
        return identity + "-\(hidesCompletedTasks ? "hide-completed" : "show-completed")"
    }

    private var taskProgress: MarkdownTaskProgress {
        MarkdownTaskProgress.make(from: text)
    }

    var body: some View {
        VStack(spacing: 0) {
            NativeTextViewWrapper(
                text: $text,
                configuration: configuration,
                fontName: NSFont.systemFont(ofSize: 14).fontName,
                fontSize: 14,
                documentId: editorRenderID,
                onPasteImage: pasteImage
            )
            .background(
                TextSelectionMonitor(
                    documentID: editorRenderID,
                    initialSelection: initialSelection,
                    requestedSelection: nil,
                    appearance: appearance,
                    hidesCompletedTasks: hidesCompletedTasks,
                    onDropImage: dropImage,
                    onSelectionChange: selectionChanged,
                    onResolve: { editor, identity in
                        editorTarget.textView = editor
                        editorTarget.documentID = identity
                    }
                )
            )
            .id(editorRenderID)
            toolbar
        }
        .background(Color(nsColor: appearance.surface))
        .onChange(of: editorRenderID) {
            selectionState.synchronize(documentID: editorRenderID, selection: initialSelection)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            ForEach(MarkdownToolbarCommand.allCases) { command in
                if command == .bullet || command == .quote {
                    Rectangle()
                        .fill(palette.border)
                        .frame(width: 1, height: 12)
                        .padding(.horizontal, 4)
                }
                Button {
                    apply(command)
                } label: {
                    Image(systemName: command.symbol)
                        .font(.system(size: 12))
                        .frame(width: 22, height: 26)
                }
                .buttonStyle(.plain)
                .help(command.title)
                .accessibilityLabel(command.title)
            }
            Spacer(minLength: 0)
            if taskProgress.completed > 0 {
                Button {
                    hidesCompletedTasks.toggle()
                } label: {
                    Image(systemName: hidesCompletedTasks ? "eye" : "eye.slash")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(hidesCompletedTasks ? "Show completed tasks" : "Hide completed tasks")
                .accessibilityLabel(hidesCompletedTasks ? "Show completed tasks" : "Hide completed tasks")
            }
            if taskProgress.total > 0 {
                ViewThatFits(in: .horizontal) {
                    Text(taskProgress.summary).fixedSize()
                    Text("\(taskProgress.completed)/\(taskProgress.total)")
                        .minimumScaleFactor(0.8)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(Color(nsColor: appearance.mutedInk))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(taskProgress.completed) of \(taskProgress.total) tasks done")
            }
        }
        .foregroundStyle(palette.isLight ? palette.ink.opacity(0.72) : palette.ink)
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(palette.toolbarSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.border.opacity(0.6)).frame(height: 0.5)
        }
    }

    private var configuration: MarkdownEditorConfiguration {
        let theme = MarkdownEditorTheme(
            bodyText: appearance.ink,
            mutedText: appearance.mutedInk,
            disabledText: .gray,
            headingMarker: appearance.mutedInk,
            link: .linkColor,
            incompleteLink: .systemBlue,
            findMatchHighlight: .systemYellow,
            findCurrentMatchHighlight: .systemOrange,
            latexLightModeText: appearance.ink,
            latexDarkModeText: appearance.ink,
            strikethroughColor: appearance.ink
        )
        let highlighterSpec = MarkdownCodeHighlighterSpec.make(
            appearance: appearance,
            isDarkTheme: palette.preferredColorScheme == .dark
        )
        let highlighter = HighlighterSwiftBridge(
            lightTheme: highlighterSpec.theme,
            darkTheme: highlighterSpec.theme,
            autoSwitchAppearance: false,
            lightBackground: highlighterSpec.background,
            darkBackground: highlighterSpec.background
        )
        let services = MarkdownEditorServices(
            images: TuckNoteImageProvider(store: imageStore),
            syntaxHighlighter: highlighter
        )
        return MarkdownEditorConfiguration(
            theme: theme,
            services: services,
            lists: ListStyle(indentPerLevel: TuckNoteTheme.markdownListIndentPerLevel),
            headings: HeadingStyle(fontMultipliers: [23.0 / 14.0, 1.4, 1.17, 1.0, 0.83, 0.67]),
            scrollers: .vertical,
            textInsets: TextInsets(
                horizontal: 29,
                vertical: 26
            )
        )
    }

    private func apply(_ command: MarkdownToolbarCommand) {
        guard editorTarget.documentID == editorRenderID,
              let editor = editorTarget.textView else { return }
        editor.window?.makeFirstResponder(editor)
        editor.setSelectedRange(selectionState.selection)
        _ = MarkdownSelectionEdit.apply(command, to: editor)
    }

    private func pasteImage(_ pasteboard: NSPasteboard) -> String? {
        MarkdownImagePaste.reference(
            from: pasteboard,
            save: imageStore.savePNG,
            onError: { _ in onImagePasteError() }
        )
    }

    private func dropImage(_ pasteboard: NSPasteboard) -> String? {
        guard let url = PasteboardImageReader.imageFileURL(from: pasteboard) else { return nil }
        return MarkdownImageDrop.reference(
            from: [url],
            save: imageStore.savePNG,
            onError: { _ in onImagePasteError() }
        )
    }

    private func selectionChanged(_ range: NSRange) {
        selectionState.selection = range
        onSelectionChange(range)
    }
}

@MainActor
private final class MarkdownEditorTarget {
    weak var textView: NSTextView?
    var documentID: String?
}

struct EditorSelectionState: Equatable {
    private(set) var documentID: String
    var selection: NSRange

    mutating func synchronize(documentID: String, selection: NSRange) {
        guard self.documentID != documentID else { return }
        self.documentID = documentID
        self.selection = selection
    }
}

struct EditorSelectionRequest: Equatable {
    let id: UUID
    let documentID: String
    let range: NSRange

    init(id: UUID = UUID(), documentID: String, range: NSRange) {
        self.id = id
        self.documentID = documentID
        self.range = range
    }
}

private struct TuckNoteImageProvider: EmbeddedImageProvider, @unchecked Sendable {
    let store: ImageStore

    func image(for reference: EmbeddedImageRequest) -> NSImage? {
        store.image(named: reference.name)
    }

    func fingerprint() -> AnyHashable {
        let filenames = (try? FileManager.default.contentsOfDirectory(
            at: store.imagesDirectory,
            includingPropertiesForKeys: nil
        ))?.map(\.lastPathComponent).sorted() ?? []
        return AnyHashable(filenames)
    }
}

private struct TextSelectionMonitor: NSViewRepresentable {
    let documentID: String
    let initialSelection: NSRange
    let requestedSelection: EditorSelectionRequest?
    let appearance: MarkdownEditorAppearance
    let hidesCompletedTasks: Bool
    let onDropImage: (NSPasteboard) -> String?
    let onSelectionChange: (NSRange) -> Void
    let onResolve: (NSTextView, String) -> Void

    func makeCoordinator() -> Coordinator {
        let coordinator = TextSelectionCoordinator(
            appearance: appearance,
            onDropImage: onDropImage,
            onSelectionChange: onSelectionChange
        )
        coordinator.onResolve = onResolve
        return coordinator
    }

    func makeNSView(context: Context) -> SelectionMonitorView {
        let view = SelectionMonitorView()
        context.coordinator.attach(
            to: view,
            documentID: documentID,
            initialSelection: initialSelection,
            requestedSelection: requestedSelection
        )
        return view
    }

    func updateNSView(_ view: SelectionMonitorView, context: Context) {
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onResolve = onResolve
        context.coordinator.onDropImage = onDropImage
        context.coordinator.appearance = appearance
        context.coordinator.hidesCompletedTasks = hidesCompletedTasks
        context.coordinator.attach(
            to: view,
            documentID: documentID,
            initialSelection: initialSelection,
            requestedSelection: requestedSelection
        )
    }

    static func dismantleNSView(_ view: SelectionMonitorView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    typealias Coordinator = TextSelectionCoordinator
}

@MainActor
final class TextSelectionCoordinator: NSObject {
    var onResolve: (NSTextView, String) -> Void = { _, _ in }
    var onSelectionChange: (NSRange) -> Void
    var onDropImage: (NSPasteboard) -> String?
    var appearance: MarkdownEditorAppearance
    var hidesCompletedTasks = false
    private(set) weak var textView: NSTextView?
    private(set) var lastAppliedRequestID: UUID?
    private weak var hostView: NSView?
    private var isObserving = false
    private var documentID: String?
    private var initialSelection = NSRange(location: 0, length: 0)
    private var requestedSelection: EditorSelectionRequest?
    private var needsInitialRestoration = false
    private var suppressSelectionChanges = false
    private var imageDropView: ImageDropView?
    private var taskCheckboxOverlayView: TaskCheckboxOverlayView?
    private var keyMonitor: Any?
    private var emphasisSource: String?
    private var emphasis = MarkdownEmphasis("")

    private func polishEmphasis(in editor: NSTextView) {
        if emphasisSource != editor.string {
            emphasisSource = editor.string
            emphasis = MarkdownEmphasis(editor.string)
        }
        emphasis.hideMarkers(in: editor)
    }

    init(
        appearance: MarkdownEditorAppearance = .tuckNote(),
        onDropImage: @escaping (NSPasteboard) -> String? = { _ in nil },
        onSelectionChange: @escaping (NSRange) -> Void
    ) {
        self.appearance = appearance
        self.onDropImage = onDropImage
        self.onSelectionChange = onSelectionChange
        super.init()
    }

    func attach(
        to view: NSView,
        documentID: String,
        initialSelection: NSRange,
        requestedSelection: EditorSelectionRequest?,
        schedule: Bool = true
    ) {
        hostView = view
        self.initialSelection = initialSelection
        self.requestedSelection = requestedSelection
        startObservingIfNeeded()

        if self.documentID != documentID {
            self.documentID = documentID
            textView = nil
            needsInitialRestoration = true
            suppressSelectionChanges = true
        }

        guard schedule else { return }
        DispatchQueue.main.async { [weak self] in
            self?.resolveAssociationAndApplySelection()
        }
    }

    func resolveAssociationAndApplySelection() {
        guard let hostView,
              let associatedTextView = Self.associatedTextView(for: hostView) else { return }
        textView = associatedTextView
        if let documentID { onResolve(associatedTextView, documentID) }
        guard !associatedTextView.hasMarkedText() else { return }
        appearance.apply(to: associatedTextView)
        TuckNoteTaskCheckboxPolisher.apply(
            to: associatedTextView,
            appearance: appearance,
            hidesCompletedTasks: hidesCompletedTasks
        )
        polishEmphasis(in: associatedTextView)
        installImageDropView(for: associatedTextView)
        installTaskCheckboxOverlay(for: associatedTextView)
        refreshTaskCheckboxOverlay()

        if needsInitialRestoration {
            let range = clamped(initialSelection, to: associatedTextView)
            associatedTextView.setSelectedRange(range)
            needsInitialRestoration = false
            suppressSelectionChanges = false
        }

        guard let requestedSelection,
              requestedSelection.documentID == documentID,
              requestedSelection.id != lastAppliedRequestID else { return }
        associatedTextView.setSelectedRange(clamped(requestedSelection.range, to: associatedTextView))
        lastAppliedRequestID = requestedSelection.id
    }

    func stopObserving() {
        NotificationCenter.default.removeObserver(self)
        isObserving = false
        imageDropView?.removeFromSuperview()
        imageDropView = nil
        taskCheckboxOverlayView?.removeFromSuperview()
        taskCheckboxOverlayView = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        textView = nil
    }

    private func startObservingIfNeeded() {
        guard !isObserving else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: nil
        )
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self else { return false }
                return self.handleKeyDown(event)
            }
            return handled ? nil : event
        }
        isObserving = true
    }

    private func installImageDropView(for textView: NSTextView) {
        guard let scrollView = textView.enclosingScrollView else { return }
        let dropView = imageDropView ?? ImageDropView()
        dropView.textView = textView
        dropView.onDropImage = { [weak self] pasteboard in
            self?.onDropImage(pasteboard)
        }
        dropView.frame = scrollView.contentView.frame
        dropView.autoresizingMask = [.width, .height]
        if dropView.superview !== scrollView {
            dropView.removeFromSuperview()
            scrollView.addSubview(dropView, positioned: .above, relativeTo: scrollView.contentView)
        }
        imageDropView = dropView
    }

    private func installTaskCheckboxOverlay(for textView: NSTextView) {
        let overlay = taskCheckboxOverlayView ?? TaskCheckboxOverlayView(frame: textView.bounds)
        overlay.textView = textView
        overlay.editorAppearance = appearance
        overlay.hidesCompletedTasks = hidesCompletedTasks
        overlay.frame = textView.bounds
        overlay.autoresizingMask = [.width, .height]
        if overlay.superview !== textView {
            overlay.removeFromSuperview()
            textView.addSubview(overlay)
        }
        taskCheckboxOverlayView = overlay
    }

    private func refreshTaskCheckboxOverlay() {
        taskCheckboxOverlayView?.editorAppearance = appearance
        taskCheckboxOverlayView?.hidesCompletedTasks = hidesCompletedTasks
        taskCheckboxOverlayView?.needsDisplay = true
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard event.window === textView?.window,
              textView?.window?.firstResponder === textView,
              event.keyCode == 36 || event.keyCode == 76 else {
            return false
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.control),
              !flags.contains(.option) else {
            return false
        }
        return toggleCurrentTask()
    }

    private func toggleCurrentTask() -> Bool {
        guard let textView,
              let edit = MarkdownTaskToggle.make(
                text: textView.string,
                selection: textView.selectedRange()
              ) else {
            return false
        }
        textView.insertText(edit.replacement, replacementRange: edit.range)
        textView.setSelectedRange(edit.selectedRange)
        TuckNoteTaskCheckboxPolisher.apply(
            to: textView,
            appearance: appearance,
            hidesCompletedTasks: hidesCompletedTasks
        )
        refreshTaskCheckboxOverlay()
        return true
    }

    @objc private func selectionDidChange(_ notification: Notification) {
        guard !suppressSelectionChanges,
              let observedTextView = notification.object as? NSTextView,
              observedTextView === textView,
              !observedTextView.hasMarkedText() else { return }
        TuckNoteTaskCheckboxPolisher.apply(
            to: observedTextView,
            appearance: appearance,
            hidesCompletedTasks: hidesCompletedTasks
        )
        polishEmphasis(in: observedTextView)
        refreshTaskCheckboxOverlay()
        // Only nudge a direct click out of a rendered marker. Keyboard edits,
        // drag selections and Select All must retain the user's exact range.
        if NSApp.currentEvent?.type == .leftMouseDown || NSApp.currentEvent?.type == .leftMouseUp {
            _ = protectSelection(in: observedTextView)
        }
        onSelectionChange(observedTextView.selectedRange())
    }

    @objc private func textDidChange(_ notification: Notification) {
        guard let observedTextView = notification.object as? NSTextView,
              observedTextView === textView,
              !observedTextView.hasMarkedText() else { return }
        TuckNoteTaskCheckboxPolisher.apply(
            to: observedTextView,
            appearance: appearance,
            hidesCompletedTasks: hidesCompletedTasks
        )
        polishEmphasis(in: observedTextView)
        refreshTaskCheckboxOverlay()
    }

    private func protectSelection(in textView: NSTextView) -> NSRange {
        let protectedRange = MarkdownTaskCursorProtection.protect(
            text: textView.string,
            selection: textView.selectedRange()
        )
        if protectedRange != textView.selectedRange() {
            suppressSelectionChanges = true
            textView.setSelectedRange(protectedRange)
            suppressSelectionChanges = false
        }
        return protectedRange
    }

    private func clamped(_ range: NSRange, to textView: NSTextView) -> NSRange {
        let length = (textView.string as NSString).length
        let location = min(max(range.location, 0), length)
        return NSRange(
            location: location,
            length: min(max(range.length, 0), length - location)
        )
    }

    private static func associatedTextView(for monitor: NSView) -> NSTextView? {
        var ancestor = monitor.superview
        while let candidate = ancestor {
            let textViews = descendantTextViews(in: candidate)
            if textViews.count == 1 {
                return textViews[0]
            }
            ancestor = candidate.superview
        }
        return nil
    }

    private static func descendantTextViews(in view: NSView) -> [NSTextView] {
        var result: [NSTextView] = []
        if let textView = view as? NSTextView {
            result.append(textView)
        }
        for subview in view.subviews {
            result.append(contentsOf: descendantTextViews(in: subview))
        }
        return result
    }
}

@MainActor
final class ImageDropView: NSView {
    weak var textView: NSTextView?
    var onDropImage: (NSPasteboard) -> String? = { _ in nil }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        PasteboardImageReader.imageFileURL(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        PasteboardImageReader.imageFileURL(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let textView,
              let reference = onDropImage(sender.draggingPasteboard) else {
            return false
        }
        let point = textView.convert(sender.draggingLocation, from: nil)
        let insertionLocation = textView.characterIndexForInsertion(at: point)
        guard let edit = MarkdownImageDropEdit.make(
            reference: reference,
            text: textView.string,
            insertionLocation: insertionLocation
        ) else {
            return false
        }
        textView.insertText(edit.replacement, replacementRange: edit.range)
        textView.setSelectedRange(edit.selectedRange)
        return true
    }
}

final class SelectionMonitorView: NSView {
    override var intrinsicContentSize: NSSize { .zero }
}
