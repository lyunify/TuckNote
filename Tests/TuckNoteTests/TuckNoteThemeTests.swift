import XCTest
@testable import TuckNote

final class TuckNoteThemeTests: XCTestCase {
    func testShellDimensionsArePositive() {
        let dimensions = [
            TuckNoteTheme.toolbarHeight,
            TuckNoteTheme.shellHorizontalPadding,
            TuckNoteTheme.shellVerticalPadding,
            TuckNoteTheme.shellVerticalSpacing,
            TuckNoteTheme.toolbarSpacing,
            TuckNoteTheme.pageIndicatorSize,
            TuckNoteTheme.activePageIndicatorWidth,
            TuckNoteTheme.bodyFontSize,
            TuckNoteTheme.editorPadding,
            TuckNoteTheme.editorCornerRadius,
            TuckNoteTheme.compactHandleWidth,
            TuckNoteTheme.compactHandleHeight,
            TuckNoteTheme.compactHandleBottomPadding
        ]

        XCTAssertTrue(dimensions.allSatisfy { $0 > 0 })
    }

    func testActivePageIndicatorIsWiderThanInactiveIndicator() {
        XCTAssertGreaterThan(
            TuckNoteTheme.activePageIndicatorWidth,
            TuckNoteTheme.pageIndicatorSize
        )
    }
}
