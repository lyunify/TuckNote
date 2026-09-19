import SwiftUI

enum NotebookAccessibility {
    static let addPageLabel = "Add page"
    static let removePageLabel = "Remove page"
    static let settingsLabel = "Settings"
    static let pinPanelLabel = "Keep TuckNotes open"
    static let unpinPanelLabel = "Auto-hide TuckNotes"
    static let switchToDarkThemeLabel = "Switch to dark theme"
    static let switchToLightThemeLabel = "Switch to light theme"
    static let dismissNoticeLabel = "Dismiss notice"

    static func pageLabel(position: Int, count: Int) -> String {
        "Page \(position) of \(count)"
    }
}

struct CompactNotchView: View {
    let palette: TuckNotePalette

    init(palette: TuckNotePalette = TuckNoteTheme.light) {
        self.palette = palette
    }

    var body: some View {
        RoundedRectangle(cornerRadius: TuckNoteTheme.compactCornerRadius)
            .fill(palette.shell)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(palette.ink)
                    .frame(
                        width: TuckNoteTheme.compactHandleWidth,
                        height: TuckNoteTheme.compactHandleHeight
                    )
                    .padding(.bottom, TuckNoteTheme.compactHandleBottomPadding)
            }
    }
}

struct NotebookView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settings: AppSettings
    let imageStore: ImageStore
    var onOpenSettings: () -> Void = {}
    @FocusState private var focusedPage: UUID?

    private var palette: TuckNotePalette {
        TuckNoteTheme.palette(for: settings.themeMode)
    }

    private var markdown: Binding<String> {
        let pageID = store.activePage.id
        return Binding(
            get: { store.notebook.pages.first(where: { $0.id == pageID })?.markdown ?? "" },
            set: { store.updateMarkdown($0, pageID: pageID) }
        )
    }

    var body: some View {
        let pageID = store.activePage.id
        VStack(spacing: TuckNoteTheme.shellVerticalSpacing) {
            HStack(spacing: TuckNoteTheme.toolbarSpacing) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TuckNoteTheme.toolbarSpacing) {
                            ForEach(store.notebook.pages) { page in
                                Button {
                                    store.selectPage(page.id)
                                    focusedPage = page.id
                                } label: {
                                    Capsule()
                                        .fill(page.id == store.notebook.activePageID
                                              ? palette.ink
                                              : palette.ink.opacity(0.45))
                                        .frame(
                                            width: page.id == store.notebook.activePageID
                                                ? TuckNoteTheme.activePageIndicatorWidth
                                                : TuckNoteTheme.pageIndicatorSize,
                                            height: TuckNoteTheme.pageIndicatorSize
                                        )
                                        .frame(minWidth: 22, minHeight: 24)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(page.id)
                                .focusable()
                                .focused($focusedPage, equals: page.id)
                                .onKeyPress(.leftArrow) { movePage(-1); return .handled }
                                .onKeyPress(.rightArrow) { movePage(1); return .handled }
                                .accessibilityLabel(
                                    NotebookAccessibility.pageLabel(
                                        position: pageNumber(for: page),
                                        count: store.notebook.pages.count
                                    )
                                )
                                .help(
                                    NotebookAccessibility.pageLabel(
                                        position: pageNumber(for: page),
                                        count: store.notebook.pages.count
                                    )
                                )
                            }
                        }
                    }
                    .onChange(of: store.notebook.activePageID) {
                        proxy.scrollTo(store.notebook.activePageID, anchor: .center)
                    }
                    .onAppear { proxy.scrollTo(store.notebook.activePageID, anchor: .center) }
                }
                shellButton(
                    symbol: settings.themeMode == .dark ? "sun.max" : "moon",
                    label: settings.themeMode == .dark
                        ? NotebookAccessibility.switchToLightThemeLabel
                        : NotebookAccessibility.switchToDarkThemeLabel
                ) {
                    settings.toggleTheme()
                }
                shellButton(
                    symbol: settings.isPanelPinned ? "pin.fill" : "pin",
                    label: settings.isPanelPinned
                        ? NotebookAccessibility.unpinPanelLabel
                        : NotebookAccessibility.pinPanelLabel
                ) {
                    settings.isPanelPinned.toggle()
                }
                shellButton(
                    symbol: "minus",
                    label: NotebookAccessibility.removePageLabel,
                    action: store.removeActivePage
                )
                shellButton(
                    symbol: "plus",
                    label: NotebookAccessibility.addPageLabel,
                    action: store.addPage
                )
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .frame(width: TuckNoteTheme.controlSize, height: TuckNoteTheme.controlSize)
                }
                .buttonStyle(.plain)
                .focusable()
                .accessibilityLabel(NotebookAccessibility.settingsLabel)
                .help(NotebookAccessibility.settingsLabel)
            }
            .frame(height: TuckNoteTheme.toolbarHeight)
            .foregroundStyle(palette.ink)

            if let notice = store.notice {
                HStack(spacing: TuckNoteTheme.toolbarSpacing) {
                    Image(systemName: "exclamationmark.circle")
                        .accessibilityHidden(true)
                    Text(notice)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: store.dismissNotice) {
                        Image(systemName: "xmark")
                            .frame(
                                width: TuckNoteTheme.controlSize,
                                height: TuckNoteTheme.controlSize
                            )
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .accessibilityLabel(NotebookAccessibility.dismissNoticeLabel)
                    .help(NotebookAccessibility.dismissNoticeLabel)
                }
                .foregroundStyle(palette.ink)
                .padding(.leading, TuckNoteTheme.editorPadding)
                .background(palette.paper)
                .clipShape(RoundedRectangle(cornerRadius: TuckNoteTheme.editorCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: TuckNoteTheme.editorCornerRadius)
                        .stroke(palette.border, lineWidth: 1)
                }
            }

            MarkdownEditorView(
                text: markdown,
                documentID: store.activePage.id.uuidString,
                imageStore: imageStore,
                palette: palette,
                initialSelection: NSRange(
                    location: store.activePage.selectionLocation,
                    length: store.activePage.selectionLength
                ),
                onSelectionChange: { range in
                    store.updateSelection(location: range.location, length: range.length, pageID: pageID)
                },
                onImagePasteError: {
                    store.showNotice("Could not save pasted image.")
                }
            )
                .id(pageID)
                .background(palette.editor)
                .clipShape(RoundedRectangle(cornerRadius: TuckNoteTheme.editorCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: TuckNoteTheme.editorCornerRadius)
                        .stroke(palette.border, lineWidth: 1)
                }
        }
        .padding(.horizontal, TuckNoteTheme.shellHorizontalPadding)
        .padding(.vertical, TuckNoteTheme.shellVerticalPadding)
        .background(palette.shell)
        .clipShape(RoundedRectangle(cornerRadius: TuckNoteTheme.expandedCornerRadius))
        .tint(palette.accent)
        .preferredColorScheme(palette.preferredColorScheme)
    }

    private func pageNumber(for page: NotePage) -> Int {
        (store.notebook.pages.firstIndex(where: { $0.id == page.id }) ?? 0) + 1
    }

    private func movePage(_ offset: Int) {
        store.selectAdjacentPage(offset: offset)
        focusedPage = store.activePage.id
    }

    private func shellButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: TuckNoteTheme.controlSize, height: TuckNoteTheme.controlSize)
        }
        .buttonStyle(.plain)
        .focusable()
        .accessibilityLabel(label)
        .help(label)
    }
}
