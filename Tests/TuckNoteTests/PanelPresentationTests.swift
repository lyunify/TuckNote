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
}
