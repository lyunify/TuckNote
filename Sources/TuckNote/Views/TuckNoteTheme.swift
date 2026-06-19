import SwiftUI

enum TuckNoteTheme {
    static let rose = Color(red: 231 / 255, green: 185 / 255, blue: 186 / 255)
    static let espresso = Color(red: 89 / 255, green: 50 / 255, blue: 47 / 255)
    static let paper = Color(red: 255 / 255, green: 248 / 255, blue: 244 / 255)
    static let editor = Color(red: 246 / 255, green: 229 / 255, blue: 223 / 255)
    static let border = Color(red: 236 / 255, green: 213 / 255, blue: 205 / 255)
    static let shell = rose
    static let shellHighlight = border
    static let ink = espresso
    static let mutedInk = Color(red: 0.32, green: 0.22, blue: 0.21)
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
}
