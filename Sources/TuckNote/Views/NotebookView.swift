import SwiftUI

struct CompactNotchView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: TuckNoteTheme.compactCornerRadius)
            .fill(TuckNoteTheme.shell)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(TuckNoteTheme.shellHighlight)
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
    let imageStore: ImageStore

    private var markdown: Binding<String> {
        Binding(
            get: { store.activePage.markdown },
            set: { store.updateMarkdown($0) }
        )
    }

    var body: some View {
        VStack(spacing: TuckNoteTheme.shellVerticalSpacing) {
            HStack(spacing: TuckNoteTheme.toolbarSpacing) {
                ForEach(store.notebook.pages) { page in
                    Button {
                        store.selectPage(page.id)
                    } label: {
                        Capsule()
                            .fill(page.id == store.notebook.activePageID
                                  ? TuckNoteTheme.paper : TuckNoteTheme.shellHighlight)
                            .frame(
                                width: page.id == store.notebook.activePageID
                                    ? TuckNoteTheme.activePageIndicatorWidth
                                    : TuckNoteTheme.pageIndicatorSize,
                                height: TuckNoteTheme.pageIndicatorSize
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Page \(pageNumber(for: page))")
                }

                Spacer()
                shellButton(symbol: "minus", label: "Remove page", action: store.removeActivePage)
                shellButton(symbol: "plus", label: "Add page", action: store.addPage)
                SettingsLink {
                    Image(systemName: "gearshape")
                        .frame(width: TuckNoteTheme.controlSize, height: TuckNoteTheme.controlSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .frame(height: TuckNoteTheme.toolbarHeight)
            .foregroundStyle(TuckNoteTheme.paper)

            MarkdownEditorView(
                text: markdown,
                documentID: store.activePage.id.uuidString,
                imageStore: imageStore,
                initialSelection: NSRange(
                    location: store.activePage.selectionLocation,
                    length: store.activePage.selectionLength
                ),
                onSelectionChange: { range in
                    store.updateSelection(location: range.location, length: range.length)
                },
                onImagePasteError: {
                    store.showNotice("Could not save pasted image.")
                }
            )
                .background(TuckNoteTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: TuckNoteTheme.editorCornerRadius))

            if let notice = store.notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(TuckNoteTheme.paper)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, TuckNoteTheme.shellHorizontalPadding)
        .padding(.vertical, TuckNoteTheme.shellVerticalPadding)
        .background(TuckNoteTheme.shell)
        .clipShape(RoundedRectangle(cornerRadius: TuckNoteTheme.expandedCornerRadius))
    }

    private func pageNumber(for page: NotePage) -> Int {
        (store.notebook.pages.firstIndex(where: { $0.id == page.id }) ?? 0) + 1
    }

    private func shellButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: TuckNoteTheme.controlSize, height: TuckNoteTheme.controlSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
