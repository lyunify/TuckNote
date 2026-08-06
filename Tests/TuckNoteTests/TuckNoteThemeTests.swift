import AppKit
import SwiftUI
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
            TuckNoteTheme.markdownTextInsetHorizontal,
            TuckNoteTheme.markdownListIndentPerLevel,
            TuckNoteTheme.compactHandleWidth,
            TuckNoteTheme.compactHandleHeight,
            TuckNoteTheme.compactHandleBottomPadding
        ]

        XCTAssertTrue(dimensions.allSatisfy { $0 > 0 })
    }

    func testMarkdownTextInsetIsTightEnoughForLists() {
        XCTAssertEqual(TuckNoteTheme.markdownTextInsetHorizontal, 12)
        XCTAssertEqual(TuckNoteTheme.markdownListIndentPerLevel, 4)
    }

    func testActivePageIndicatorIsWiderThanInactiveIndicator() {
        XCTAssertGreaterThan(
            TuckNoteTheme.activePageIndicatorWidth,
            TuckNoteTheme.pageIndicatorSize
        )
    }

    func testFinalBrandColorsMatchApprovedHexValues() {
        XCTAssertEqual(hex(TuckNoteTheme.rose), "#E7B9BA")
        XCTAssertEqual(hex(TuckNoteTheme.espresso), "#59322F")
        XCTAssertEqual(hex(TuckNoteTheme.paper), "#FFF8F4")
        XCTAssertEqual(hex(TuckNoteTheme.editor), "#F6E5DF")
        XCTAssertEqual(hex(TuckNoteTheme.border), "#ECD5CD")
        XCTAssertEqual(TuckNoteTheme.expandedCornerRadius, 18)
    }

    func testBodyInkOnEditorMeetsWCAGAAContrast() throws {
        let foreground = try XCTUnwrap(NSColor(TuckNoteTheme.ink).usingColorSpace(.sRGB))
        let background = try XCTUnwrap(NSColor(TuckNoteTheme.editor).usingColorSpace(.sRGB))

        XCTAssertGreaterThanOrEqual(contrastRatio(foreground, background), 4.5)
    }

    func testDarkPaletteKeepsReadableEditorContrast() throws {
        let palette = TuckNoteTheme.palette(for: .dark)
        let foreground = try XCTUnwrap(NSColor(palette.ink).usingColorSpace(.sRGB))
        let background = try XCTUnwrap(NSColor(palette.editor).usingColorSpace(.sRGB))

        XCTAssertEqual(hex(palette.shell), "#000000")
        XCTAssertEqual(hex(palette.editor), "#101010")
        XCTAssertEqual(hex(palette.ink), "#F7F7F2")
        XCTAssertEqual(palette.preferredColorScheme, .dark)
        XCTAssertGreaterThanOrEqual(contrastRatio(foreground, background), 4.5)
    }

    func testLightPalettePreservesApprovedBrandColors() {
        let palette = TuckNoteTheme.palette(for: .light)

        XCTAssertEqual(hex(palette.shell), "#E7B9BA")
        XCTAssertEqual(hex(palette.ink), "#59322F")
        XCTAssertEqual(hex(palette.accent), "#F3C56B")
        XCTAssertEqual(palette.preferredColorScheme, .light)
    }

    private func hex(_ color: SwiftUI.Color) -> String? {
        guard let color = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        let values = [color.redComponent, color.greenComponent, color.blueComponent]
            .map { Int(($0 * 255).rounded()) }
        return String(format: "#%02X%02X%02X", values[0], values[1], values[2])
    }

    private func contrastRatio(_ foreground: NSColor, _ background: NSColor) -> CGFloat {
        let brighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (brighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: NSColor) -> CGFloat {
        [color.redComponent, color.greenComponent, color.blueComponent]
            .map { component in
                component <= 0.04045
                    ? component / 12.92
                    : pow((component + 0.055) / 1.055, 2.4)
            }
            .enumerated()
            .reduce(0) { result, item in
                result + item.element * [0.2126, 0.7152, 0.0722][item.offset]
            }
    }
}
