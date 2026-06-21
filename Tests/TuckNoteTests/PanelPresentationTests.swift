import QuartzCore
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

    func testStatusMenuShowPresentsTheKeyboardAccessibleEditor() {
        XCTAssertEqual(PanelPresentation.statusMenuShow, .expanded)
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
        guard case let .reducedMotion(specification) = PanelAnimationSpec.make(reduceMotion: true)
        else { return XCTFail("Expected the fixed reduced-motion policy") }

        XCTAssertEqual(
            specification,
            PanelReducedMotionSpecification(
                duration: 0.120,
                curve: .easeOut,
                fades: true,
                resizes: true
            )
        )
    }

    func testStandardMotionCreatesPhysicalSpringAnimation() {
        guard case let .spring(specification) = PanelAnimationSpec.make(reduceMotion: false)
        else { return XCTFail("Expected a physical spring policy") }

        let animation = specification.makeAnimation(
            from: CATransform3DMakeScale(0.5, 0.25, 1)
        )

        XCTAssertEqual(animation.keyPath, "transform")
        XCTAssertEqual(animation.mass, 1)
        XCTAssertEqual(animation.stiffness, 320)
        XCTAssertEqual(animation.damping, 28)
        XCTAssertEqual(animation.initialVelocity, 0)
        XCTAssertGreaterThan(animation.settlingDuration, 0.120)
        XCTAssertEqual(animation.fromValue as? NSValue, NSValue(caTransform3D: CATransform3DMakeScale(0.5, 0.25, 1)))
        XCTAssertEqual(animation.toValue as? NSValue, NSValue(caTransform3D: CATransform3DIdentity))
    }
}
