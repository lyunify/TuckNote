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
    @FocusState private var focusedControl: String?
    @State private var renamingPageID: UUID?
    @State private var titleDraft = ""
    @State private var isRenaming = false
    @State private var deletingPageID: UUID?
    @State private var isDeleting = false

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
        VStack(spacing: 0) {
            header

            if let notice = store.notice {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                    Text(notice).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: store.dismissNotice) {
                        Image(systemName: "xmark").frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NotebookAccessibility.dismissNoticeLabel)
                }
                .padding(.leading, 12)
                .foregroundStyle(palette.ink)
                .background(palette.paper)
            }

            MarkdownEditorView(
                text: markdown,
                documentID: pageID.uuidString,
                imageStore: imageStore,
                palette: palette,
                initialSelection: NSRange(
                    location: store.activePage.selectionLocation,
                    length: store.activePage.selectionLength
                ),
                onSelectionChange: { range in
                    store.updateSelection(location: range.location, length: range.length, pageID: pageID)
                },
                onImagePasteError: { store.showNotice("Could not save pasted image.") }
            )
            .id(pageID)
            .background(palette.editor)
        }
        .background(LinearGradient(colors: [palette.shellTop, palette.shellBottom],
                                   startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            if palette.isLight {
                RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.9), lineWidth: 1)
                RoundedRectangle(cornerRadius: 20).strokeBorder(palette.ink.opacity(0.09), lineWidth: 0.5)
            } else {
                RoundedRectangle(cornerRadius: 20).strokeBorder(palette.border.opacity(0.8), lineWidth: 0.5)
            }
        }
        .tint(palette.accent)
        .preferredColorScheme(palette.preferredColorScheme)
        .alert("Rename page", isPresented: $isRenaming) {
            TextField("Page name", text: $titleDraft)
            Button("Cancel", role: .cancel) { renamingPageID = nil }
            Button("Save") {
                if let id = renamingPageID { store.renamePage(id, to: titleDraft) }
                renamingPageID = nil
            }
            .disabled(titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Choose a name up to 40 characters. Your note content stays the same.")
        }
        .alert("Remove this page?", isPresented: $isDeleting) {
            Button("Cancel", role: .cancel) { deletingPageID = nil }
            Button("Remove", role: .destructive) {
                if let id = deletingPageID { store.removePage(id) }
                deletingPageID = nil
            }
        } message: {
            Text("This page's contents will be removed. This cannot be undone. If it is your only page, it will be cleared instead.")
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text("TuckNotes")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                shellControls
            }
            .frame(height: 48)

            HStack(spacing: 10) {
                pageTabs
                shellButton(symbol: "plus", label: NotebookAccessibility.addPageLabel,
                            action: store.addPage)
                    .background(palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(.bottom, 8)
            .frame(height: 40)
        }
        .padding(.horizontal, 16)
        .foregroundStyle(palette.ink)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border.opacity(0.7))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
        }
    }

    private var pageTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(store.notebook.pages) { page in
                        Button {
                            store.selectPage(page.id)
                            focusedPage = page.id
                        } label: {
                            pageTabLabel(page)
                        }
                        .buttonStyle(.plain)
                        .id(page.id)
                        .focusable()
                        .focused($focusedPage, equals: page.id)
                        .onKeyPress(.leftArrow) { movePage(-1); return .handled }
                        .onKeyPress(.rightArrow) { movePage(1); return .handled }
                        .accessibilityLabel("\(pageTitle(page)), \(NotebookAccessibility.pageLabel(position: pageNumber(for: page), count: store.notebook.pages.count))")
                        .accessibilityAddTraits(page.id == store.notebook.activePageID ? [.isSelected] : [])
                        .help("\(pageTitle(page)). Right-click for page options.")
                        .contextMenu {
                            Button("Rename...") {
                                renamingPageID = page.id
                                titleDraft = pageTitle(page)
                                isRenaming = true
                            }
                            Divider()
                            Button("Remove page...", role: .destructive) {
                                deletingPageID = page.id
                                isDeleting = true
                            }
                        }
                    }
                }
            }
            .onChange(of: store.notebook.activePageID) {
                proxy.scrollTo(store.notebook.activePageID, anchor: .center)
            }
            .onAppear { proxy.scrollTo(store.notebook.activePageID, anchor: .center) }
        }
    }

    private var shellControls: some View {
        HStack(spacing: 4) {
            shellButton(
                symbol: settings.themeMode == .dark ? "sun.max" : "moon",
                label: settings.themeMode == .dark
                    ? NotebookAccessibility.switchToLightThemeLabel
                    : NotebookAccessibility.switchToDarkThemeLabel
            ) { settings.toggleTheme() }
            shellButton(
                symbol: settings.isPanelPinned ? "pin.fill" : "pin",
                label: settings.isPanelPinned ? NotebookAccessibility.unpinPanelLabel : NotebookAccessibility.pinPanelLabel,
                isSelected: settings.isPanelPinned
            ) { settings.isPanelPinned.toggle() }
            shellButton(symbol: "gearshape", label: NotebookAccessibility.settingsLabel, action: onOpenSettings)
        }
        .fixedSize()
    }

    @ViewBuilder
    private func pageTabLabel(_ page: NotePage) -> some View {
        let isSelected = page.id == store.notebook.activePageID
        if page.isCompactTab ?? (pageNumber(for: page) > 3) {
            Capsule()
                .fill(isSelected ? palette.accent : palette.mutedInk.opacity(0.45))
                .frame(width: isSelected ? 16 : 6, height: 6)
                .frame(width: 20, height: 28)
                .contentShape(Rectangle())
        } else {
            Text(pageTitle(page))
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .frame(minWidth: 44, maxWidth: 130)
                .foregroundStyle(isSelected ? palette.ink : palette.mutedInk)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? palette.accent.opacity(0.15) : .clear)
                }
                .contentShape(Rectangle())
        }
    }

    private func pageTitle(_ page: NotePage) -> String {
        page.title ?? Notebook.defaultTitle(at: pageNumber(for: page) - 1)
    }

    private func pageNumber(for page: NotePage) -> Int {
        (store.notebook.pages.firstIndex { $0.id == page.id } ?? 0) + 1
    }

    private func movePage(_ offset: Int) {
        store.selectAdjacentPage(offset: offset)
        focusedPage = store.activePage.id
    }

    private func shellButton(symbol: String, label: String, isSelected: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
                .foregroundStyle(isSelected ? palette.accent : palette.mutedInk)
                .background(isSelected ? palette.accent.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedControl, equals: label)
        .focusEffectDisabled()
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(focusedControl == label ? palette.accent.opacity(0.65) : .clear, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityLabel(label)
        .help(label)
    }
}
