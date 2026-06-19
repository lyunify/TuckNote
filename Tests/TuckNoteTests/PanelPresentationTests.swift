import XCTest
@testable import TuckNote

final class PanelPresentationTests: XCTestCase {
    func testCompactPresentationShowsOnlyCompactPanel() {
        let presentation = PanelPresentation.compact

        XCTAssertTrue(presentation.showsCompactPanel)
        XCTAssertFalse(presentation.showsExpandedPanel)
    }

    func testExpandedPresentationShowsOnlyExpandedPanel() {
        let presentation = PanelPresentation.expanded

        XCTAssertFalse(presentation.showsCompactPanel)
        XCTAssertTrue(presentation.showsExpandedPanel)
    }

    func testToggleAlternatesPresentation() {
        XCTAssertEqual(PanelPresentation.compact.toggled, .expanded)
        XCTAssertEqual(PanelPresentation.expanded.toggled, .compact)
    }

    func testHoverDwellTriggersAfter120MillisecondsInside() {
        var dwell = HoverDwellState(duration: 0.120)

        XCTAssertFalse(dwell.update(isInside: true, now: 10))
        XCTAssertFalse(dwell.update(isInside: true, now: 10.119))
        XCTAssertTrue(dwell.update(isInside: true, now: 10.120))
    }

    func testHoverDwellResetsAfterLeavingTarget() {
        var dwell = HoverDwellState(duration: 0.120)

        XCTAssertFalse(dwell.update(isInside: true, now: 10))
        XCTAssertFalse(dwell.update(isInside: false, now: 10.100))
        XCTAssertFalse(dwell.update(isInside: true, now: 10.200))
        XCTAssertFalse(dwell.update(isInside: true, now: 10.319))
        XCTAssertTrue(dwell.update(isInside: true, now: 10.320))
    }

    func testPageAccessibilityLabelIncludesPositionAndCount() {
        XCTAssertEqual(NotebookAccessibility.pageLabel(position: 2, count: 5), "Page 2 of 5")
        XCTAssertEqual(NotebookAccessibility.addPageLabel, "Add page")
        XCTAssertEqual(NotebookAccessibility.removePageLabel, "Remove page")
        XCTAssertEqual(NotebookAccessibility.settingsLabel, "Settings")
        XCTAssertEqual(NotebookAccessibility.dismissNoticeLabel, "Dismiss notice")
    }

    func testReducedMotionUses120MillisecondEaseOutFadeAndResize() {
        XCTAssertEqual(
            PanelAnimationSpec.make(reduceMotion: true),
            PanelAnimationSpec(duration: 0.120, curve: .easeOut, fades: true, resizes: true)
        )
    }

    func testStandardMotionUsesSpringResize() {
        XCTAssertEqual(
            PanelAnimationSpec.make(reduceMotion: false),
            PanelAnimationSpec(duration: 0.22, curve: .spring, fades: false, resizes: true)
        )
    }
}
