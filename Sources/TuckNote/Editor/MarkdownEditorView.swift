import AppKit
import MarkdownEngine
import SwiftUI

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
        case .bold, .italic:
            return nil
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
            return blockEdit(prefix: "- ", text: nsText, selection: selection)
        case .numbered:
            return blockEdit(prefix: "1. ", text: nsText, selection: selection)
        case .task:
            return blockEdit(prefix: "- [ ] ", text: nsText, selection: selection)
        case .quote:
            return blockEdit(prefix: "> ", text: nsText, selection: selection)
        }
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

@MainActor
struct MarkdownEditorAppearance {
    let surface: NSColor
    let ink: NSColor

    static let tuckNote = Self(
        surface: NSColor(TuckNoteTheme.editor),
        ink: NSColor(TuckNoteTheme.ink)
    )

    func apply(to textView: NSTextView) {
        textView.drawsBackground = true
        textView.backgroundColor = surface
        textView.insertionPointColor = ink
        guard let scrollView = textView.enclosingScrollView else { return }
        scrollView.drawsBackground = true
        scrollView.backgroundColor = surface
    }
}

struct MarkdownEditorView: View {
    @Binding private var text: String
    let documentID: String
    let imageStore: ImageStore
    let initialSelection: NSRange
    let onSelectionChange: (NSRange) -> Void
    let onImagePasteError: () -> Void

    @State private var selection: NSRange
    @State private var pendingReplacement: InlineReplacementRequest?
    @State private var requestedSelection: EditorSelectionRequest?

    private let boldRequest = Notification.Name("TuckNote.Markdown.Bold")
    private let italicRequest = Notification.Name("TuckNote.Markdown.Italic")
    private let appearance = MarkdownEditorAppearance.tuckNote

    init(
        text: Binding<String>,
        documentID: String,
        imageStore: ImageStore,
        initialSelection: NSRange = .init(location: 0, length: 0),
        onSelectionChange: @escaping (NSRange) -> Void,
        onImagePasteError: @escaping () -> Void = {}
    ) {
        _text = text
        self.documentID = documentID
        self.imageStore = imageStore
        self.initialSelection = initialSelection
        self.onSelectionChange = onSelectionChange
        self.onImagePasteError = onImagePasteError
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            NativeTextViewWrapper(
                text: $text,
                pendingInlineReplacement: $pendingReplacement,
                configuration: configuration,
                fontName: NSFont.systemFont(ofSize: 14).fontName,
                fontSize: 14,
                documentId: documentID,
                onPasteImage: pasteImage
            )
            .background(
                TextSelectionMonitor(
                    documentID: documentID,
                    initialSelection: initialSelection,
                    requestedSelection: requestedSelection,
                    appearance: appearance,
                    onSelectionChange: selectionChanged
                )
            )
        }
        .background(Color(nsColor: appearance.surface))
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(MarkdownToolbarCommand.allCases) { command in
                Button {
                    apply(command)
                } label: {
                    Image(systemName: command.symbol)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(command.title)
                .accessibilityLabel(command.title)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(nsColor: appearance.ink))
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color(nsColor: appearance.surface))
    }

    private var configuration: MarkdownEditorConfiguration {
        let theme = MarkdownEditorTheme(
            bodyText: appearance.ink,
            mutedText: .darkGray,
            disabledText: .gray,
            headingMarker: .darkGray,
            link: .linkColor,
            incompleteLink: .systemBlue,
            findMatchHighlight: .systemYellow,
            findCurrentMatchHighlight: .systemOrange,
            latexLightModeText: .black,
            latexDarkModeText: .black,
            strikethroughColor: .black
        )
        let services = MarkdownEditorServices(
            images: TuckNoteImageProvider(store: imageStore),
            bus: MarkdownEditorBus(
                applyBoldRequest: boldRequest,
                applyItalicRequest: italicRequest
            )
        )
        return MarkdownEditorConfiguration(
            theme: theme,
            services: services,
            scrollers: .vertical,
            textInsets: TextInsets(horizontal: 14, vertical: 14)
        )
    }

    private func apply(_ command: MarkdownToolbarCommand) {
        switch command {
        case .bold:
            NotificationCenter.default.post(name: boldRequest, object: nil)
        case .italic:
            NotificationCenter.default.post(name: italicRequest, object: nil)
        default:
            guard let edit = MarkdownSelectionEdit.make(
                command: command,
                text: text,
                selection: selection
            ) else { return }
            requestedSelection = EditorSelectionRequest(
                documentID: documentID,
                range: edit.selectedRange
            )
            pendingReplacement = InlineReplacementRequest(
                documentId: documentID,
                selection: WikiLinkSelection(
                    displayRange: edit.range,
                    storageRange: edit.range,
                    placeholder: ""
                ),
                storageFragment: edit.replacement,
                isImageEmbedMode: true
            )
        }
    }

    private func pasteImage(_ pasteboard: NSPasteboard) -> String? {
        MarkdownImagePaste.reference(
            from: pasteboard,
            save: imageStore.savePNG,
            onError: { _ in onImagePasteError() }
        )
    }

    private func selectionChanged(_ range: NSRange) {
        selection = range
        onSelectionChange(range)
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
    let onSelectionChange: (NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        TextSelectionCoordinator(appearance: appearance, onSelectionChange: onSelectionChange)
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
        context.coordinator.appearance = appearance
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
    var onSelectionChange: (NSRange) -> Void
    var appearance: MarkdownEditorAppearance
    private(set) weak var textView: NSTextView?
    private(set) var lastAppliedRequestID: UUID?
    private weak var hostView: NSView?
    private var isObserving = false
    private var documentID: String?
    private var initialSelection = NSRange(location: 0, length: 0)
    private var requestedSelection: EditorSelectionRequest?
    private var needsInitialRestoration = false
    private var suppressSelectionChanges = false

    init(
        appearance: MarkdownEditorAppearance = .tuckNote,
        onSelectionChange: @escaping (NSRange) -> Void
    ) {
        self.appearance = appearance
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
        appearance.apply(to: associatedTextView)

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
        isObserving = true
    }

    @objc private func selectionDidChange(_ notification: Notification) {
        guard !suppressSelectionChanges,
              let observedTextView = notification.object as? NSTextView,
              observedTextView === textView else { return }
        onSelectionChange(observedTextView.selectedRange())
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

final class SelectionMonitorView: NSView {
    override var intrinsicContentSize: NSSize { .zero }
}
