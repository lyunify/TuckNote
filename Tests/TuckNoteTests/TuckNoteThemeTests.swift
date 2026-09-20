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
        XCTAssertEqual(hex(TuckNoteTheme.rose), "#EEF1F7")
        XCTAssertEqual(hex(TuckNoteTheme.espresso), "#293345")
        XCTAssertEqual(hex(TuckNoteTheme.paper), "#FCFDFF")
        XCTAssertEqual(hex(TuckNoteTheme.editor), "#FCFDFF")
        XCTAssertEqual(hex(TuckNoteTheme.border), "#DCE2ED")
        XCTAssertEqual(TuckNoteTheme.expandedCornerRadius, 18)
    }

    func testBodyInkOnEditorMeetsWCAGAAContrast() throws {
        let foreground = try XCTUnwrap(NSColor(TuckNoteTheme.ink).usingColorSpace(.sRGB))
        let background = try XCTUnwrap(NSColor(TuckNoteTheme.editor).usingColorSpace(.sRGB))

        XCTAssertGreaterThanOrEqual(contrastRatio(foreground, background), 4.5)
    }

    func testSecondaryLightTextRemainsReadable() throws {
        let palette = TuckNoteTheme.light
        let foreground = try XCTUnwrap(NSColor(palette.mutedInk).usingColorSpace(.sRGB))
        for surface in [palette.editor, palette.shell] {
            let background = try XCTUnwrap(NSColor(surface).usingColorSpace(.sRGB))
            XCTAssertGreaterThanOrEqual(contrastRatio(foreground, background), 4.5)
        }
    }

    func testDarkPaletteKeepsReadableEditorContrast() throws {
        let palette = TuckNoteTheme.palette(for: .dark)
        let foreground = try XCTUnwrap(NSColor(palette.ink).usingColorSpace(.sRGB))
        let background = try XCTUnwrap(NSColor(palette.editor).usingColorSpace(.sRGB))

        XCTAssertEqual(hex(palette.shell), "#202734")
        XCTAssertEqual(hex(palette.editor), "#171C24")
        XCTAssertEqual(hex(palette.ink), "#E8EDF7")
        XCTAssertEqual(hex(palette.accent), "#7486BB")
        XCTAssertEqual(palette.preferredColorScheme, .dark)
        XCTAssertGreaterThanOrEqual(contrastRatio(foreground, background), 4.5)
    }

    func testLightPalettePreservesApprovedBrandColors() {
        let palette = TuckNoteTheme.palette(for: .light)

        XCTAssertEqual(hex(palette.shell), "#EEF1F7")
        XCTAssertEqual(hex(palette.ink), "#293345")
        XCTAssertEqual(hex(palette.accent), "#7486BB")
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
        let red = linearized(color.redComponent)
        let green = linearized(color.greenComponent)
        let blue = linearized(color.blueComponent)

        return red * 0.2126 + green * 0.7152 + blue * 0.0722
    }

    private func linearized(_ component: CGFloat) -> CGFloat {
        if component <= 0.04045 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }
}
