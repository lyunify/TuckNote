import SwiftUI

struct TuckNotePalette {
    let rose: Color
    let espresso: Color
    let paper: Color
    let editor: Color
    let border: Color
    let shell: Color
    let shellHighlight: Color
    let ink: Color
    let mutedInk: Color
    let accent: Color
    let codeBlockBackground: Color
    let preferredColorScheme: ColorScheme
}

enum TuckNoteTheme {
    static let light = TuckNotePalette(
        rose: Color(red: 231 / 255, green: 185 / 255, blue: 186 / 255),
        espresso: Color(red: 89 / 255, green: 50 / 255, blue: 47 / 255),
        paper: Color(red: 255 / 255, green: 248 / 255, blue: 244 / 255),
        editor: Color(red: 246 / 255, green: 229 / 255, blue: 223 / 255),
        border: Color(red: 236 / 255, green: 213 / 255, blue: 205 / 255),
        shell: Color(red: 231 / 255, green: 185 / 255, blue: 186 / 255),
        shellHighlight: Color(red: 236 / 255, green: 213 / 255, blue: 205 / 255),
        ink: Color(red: 89 / 255, green: 50 / 255, blue: 47 / 255),
        mutedInk: Color(red: 0.32, green: 0.22, blue: 0.21),
        accent: Color(red: 243 / 255, green: 197 / 255, blue: 107 / 255),
        codeBlockBackground: Color(red: 238 / 255, green: 218 / 255, blue: 211 / 255),
        preferredColorScheme: .light
    )
    static let dark = TuckNotePalette(
        rose: Color(red: 16 / 255, green: 16 / 255, blue: 16 / 255),
        espresso: Color(red: 247 / 255, green: 247 / 255, blue: 242 / 255),
        paper: Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255),
        editor: Color(red: 16 / 255, green: 16 / 255, blue: 16 / 255),
        border: Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255),
        shell: Color(red: 0 / 255, green: 0 / 255, blue: 0 / 255),
        shellHighlight: Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255),
        ink: Color(red: 247 / 255, green: 247 / 255, blue: 242 / 255),
        mutedInk: Color(red: 0.68, green: 0.68, blue: 0.65),
        accent: Color(red: 243 / 255, green: 197 / 255, blue: 107 / 255),
        codeBlockBackground: Color(red: 28 / 255, green: 28 / 255, blue: 28 / 255),
        preferredColorScheme: .dark
    )

    static let rose = light.rose
    static let espresso = light.espresso
    static let paper = light.paper
    static let editor = light.editor
    static let border = light.border
    static let shell = light.shell
    static let shellHighlight = light.shellHighlight
    static let ink = light.ink
    static let mutedInk = light.mutedInk
    static let accent = light.accent

    static func palette(for mode: ThemeMode) -> TuckNotePalette {
        switch mode {
        case .light:
            light
        case .dark:
            dark
        }
    }

    static let compactCornerRadius: CGFloat = 11
    static let expandedCornerRadius: CGFloat = 18
    static let compactHandleWidth: CGFloat = 38
    static let compactHandleHeight: CGFloat = 3
    static let compactHandleBottomPadding: CGFloat = 5
    static let shellHorizontalPadding: CGFloat = 18
    static let shellVerticalPadding: CGFloat = 18
    static let shellVerticalSpacing: CGFloat = 12
    static let toolbarSpacing: CGFloat = 8
    static let toolbarHeight: CGFloat = 28
    static let controlSize: CGFloat = 28
    static let pageIndicatorSize: CGFloat = 9
    static let activePageIndicatorWidth: CGFloat = 18
    static let bodyFontSize: CGFloat = 15
    static let editorPadding: CGFloat = 10
    static let editorCornerRadius: CGFloat = 13
    static let markdownTextInsetHorizontal: CGFloat = 12
    static let markdownTextInsetVertical: CGFloat = 14
    static let markdownListIndentPerLevel: CGFloat = 4
    static let markdownTaskParagraphSpacing: CGFloat = 6
}
