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

struct MarkdownEditorView: View {
    @Binding private var text: String
    let documentID: String
    let imageStore: ImageStore
    let initialSelection: NSRange
    let onSelectionChange: (NSRange) -> Void
    let onImagePasteError: () -> Void

    @State private var selection: NSRange
    @State private var pendingReplacement: InlineReplacementRequest?

    private let boldRequest = Notification.Name("TuckNote.Markdown.Bold")
    private let italicRequest = Notification.Name("TuckNote.Markdown.Italic")

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
                    onSelectionChange: selectionChanged
                )
            )
        }
        .background(Color.white)
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
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var configuration: MarkdownEditorConfiguration {
        let theme = MarkdownEditorTheme(
            bodyText: .black,
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
    let onSelectionChange: (NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChange: onSelectionChange)
    }

    func makeNSView(context: Context) -> SelectionMonitorView {
        let view = SelectionMonitorView()
        context.coordinator.attach(to: view, documentID: documentID, initialSelection: initialSelection)
        return view
    }

    func updateNSView(_ view: SelectionMonitorView, context: Context) {
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.attach(to: view, documentID: documentID, initialSelection: initialSelection)
    }

    static func dismantleNSView(_ view: SelectionMonitorView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectionChange: (NSRange) -> Void
        private weak var hostView: NSView?
        private var isObserving = false
        private var documentID: String?

        init(onSelectionChange: @escaping (NSRange) -> Void) {
            self.onSelectionChange = onSelectionChange
            super.init()
        }

        func attach(to view: NSView, documentID: String, initialSelection: NSRange) {
            hostView = view
            if !isObserving {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(selectionDidChange(_:)),
                    name: NSTextView.didChangeSelectionNotification,
                    object: nil
                )
                isObserving = true
            }
            guard self.documentID != documentID else { return }
            self.documentID = documentID
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let window = view?.window,
                      let textView = Self.firstTextView(in: window.contentView) else { return }
                let length = (textView.string as NSString).length
                let location = min(max(initialSelection.location, 0), length)
                let range = NSRange(
                    location: location,
                    length: min(max(initialSelection.length, 0), length - location)
                )
                textView.setSelectedRange(range)
                self.onSelectionChange(range)
            }
        }

        func stopObserving() {
            NotificationCenter.default.removeObserver(self)
            isObserving = false
        }

        @objc private func selectionDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  textView.window === hostView?.window else { return }
            onSelectionChange(textView.selectedRange())
        }

        private static func firstTextView(in view: NSView?) -> NSTextView? {
            guard let view else { return nil }
            if let textView = view as? NSTextView { return textView }
            for subview in view.subviews {
                if let textView = firstTextView(in: subview) { return textView }
            }
            return nil
        }
    }
}

private final class SelectionMonitorView: NSView {
    override var intrinsicContentSize: NSSize { .zero }
}
