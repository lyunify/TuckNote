import SwiftUI

struct CompactNotchView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: TuckNoteTheme.compactCornerRadius)
            .fill(TuckNoteTheme.shell)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(TuckNoteTheme.shellHighlight)
                    .frame(width: 38, height: 3)
                    .padding(.bottom, 5)
            }
    }
}

struct NotebookView: View {
    @ObservedObject var store: NoteStore

    private var markdown: Binding<String> {
        Binding(
            get: { store.activePage.markdown },
            set: { store.updateMarkdown($0) }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(store.notebook.pages) { page in
                    Button {
                        store.selectPage(page.id)
                    } label: {
                        Circle()
                            .fill(page.id == store.notebook.activePageID
                                  ? TuckNoteTheme.paper : TuckNoteTheme.shellHighlight)
                            .frame(width: 9, height: 9)
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
            .foregroundStyle(TuckNoteTheme.paper)

            TextEditor(text: markdown)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(TuckNoteTheme.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(TuckNoteTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 13))

            if let notice = store.notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(TuckNoteTheme.paper)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(TuckNoteTheme.contentPadding)
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
