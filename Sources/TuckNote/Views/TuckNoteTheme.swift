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

    var isLight: Bool { preferredColorScheme == .light }
    var toolbarSurface: Color { isLight ? Color(red: 245 / 255, green: 247 / 255, blue: 251 / 255) : Color(red: 29 / 255, green: 37 / 255, blue: 50 / 255) }
    var shellTop: Color { isLight ? Color(red: 250 / 255, green: 251 / 255, blue: 254 / 255) : Color(red: 37 / 255, green: 46 / 255, blue: 62 / 255) }
    var shellBottom: Color { isLight ? Color(red: 229 / 255, green: 234 / 255, blue: 243 / 255) : Color(red: 27 / 255, green: 34 / 255, blue: 48 / 255) }
}

enum TuckNoteTheme {
    static let light = TuckNotePalette(
        rose: Color(red: 238 / 255, green: 241 / 255, blue: 247 / 255),
        espresso: Color(red: 41 / 255, green: 51 / 255, blue: 69 / 255),
        paper: Color(red: 252 / 255, green: 253 / 255, blue: 255 / 255),
        editor: Color(red: 252 / 255, green: 253 / 255, blue: 255 / 255),
        border: Color(red: 220 / 255, green: 226 / 255, blue: 237 / 255),
        shell: Color(red: 238 / 255, green: 241 / 255, blue: 247 / 255),
        shellHighlight: Color(red: 250 / 255, green: 251 / 255, blue: 254 / 255),
        ink: Color(red: 41 / 255, green: 51 / 255, blue: 69 / 255),
        mutedInk: Color(red: 96 / 255, green: 109 / 255, blue: 132 / 255),
        accent: Color(red: 116 / 255, green: 134 / 255, blue: 187 / 255),
        codeBlockBackground: Color(red: 239 / 255, green: 242 / 255, blue: 248 / 255),
        preferredColorScheme: .light
    )
    static let dark = TuckNotePalette(
        rose: Color(red: 32 / 255, green: 39 / 255, blue: 52 / 255),
        espresso: Color(red: 232 / 255, green: 237 / 255, blue: 247 / 255),
        paper: Color(red: 23 / 255, green: 28 / 255, blue: 36 / 255),
        editor: Color(red: 23 / 255, green: 28 / 255, blue: 36 / 255),
        border: Color(red: 53 / 255, green: 64 / 255, blue: 85 / 255),
        shell: Color(red: 32 / 255, green: 39 / 255, blue: 52 / 255),
        shellHighlight: Color(red: 53 / 255, green: 64 / 255, blue: 85 / 255),
        ink: Color(red: 232 / 255, green: 237 / 255, blue: 247 / 255),
        mutedInk: Color(red: 156 / 255, green: 170 / 255, blue: 194 / 255),
        accent: Color(red: 116 / 255, green: 134 / 255, blue: 187 / 255),
        codeBlockBackground: Color(red: 31 / 255, green: 40 / 255, blue: 55 / 255),
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
