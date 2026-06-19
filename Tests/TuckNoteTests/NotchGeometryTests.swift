import AppKit
import XCTest
@testable import TuckNote

final class NotchGeometryTests: XCTestCase {
    func testNotchedDisplayUsesAuxiliaryGapAndDesiredExpandedSize() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            visibleFrame: CGRect(x: 0, y: 38, width: 1512, height: 944),
            safeAreaInsets: NSEdgeInsets(top: 74, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 908, width: 666, height: 74),
            auxiliaryTopRightArea: CGRect(x: 846, y: 908, width: 666, height: 74)
        )

        XCTAssertTrue(geometry.hasPhysicalNotch)
        XCTAssertEqual(geometry.compactFrame.width, 180)
        XCTAssertEqual(geometry.compactFrame.midX, screenFrame.midX)
        XCTAssertEqual(geometry.compactFrame.maxY, screenFrame.maxY)
        XCTAssertEqual(geometry.expandedFrame.size, CGSize(width: 520, height: 430))
        XCTAssertEqual(geometry.expandedFrame.midX, screenFrame.midX)
        XCTAssertEqual(geometry.expandedFrame.maxY, screenFrame.maxY)
        XCTAssertTrue(screenFrame.contains(geometry.compactFrame))
        XCTAssertTrue(screenFrame.contains(geometry.expandedFrame))
    }

    func testNotchlessDisplayUsesFallbackCompactWidth() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            visibleFrame: CGRect(x: 0, y: 23, width: 1920, height: 1057),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )

        XCTAssertFalse(geometry.hasPhysicalNotch)
        XCTAssertEqual(geometry.compactFrame.width, 120)
        XCTAssertEqual(geometry.compactFrame.midX, screenFrame.midX)
        XCTAssertEqual(geometry.compactFrame.maxY, screenFrame.maxY)
    }

    func testConstrainedExternalDisplayRespectsBoundsAndScreenOrigin() {
        let screenFrame = CGRect(x: -960, y: 240, width: 480, height: 360)
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            visibleFrame: CGRect(x: -960, y: 263, width: 480, height: 337),
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )

        XCTAssertEqual(geometry.compactFrame.midX, -720)
        XCTAssertEqual(geometry.compactFrame.maxY, 600)
        XCTAssertEqual(geometry.expandedFrame, CGRect(x: -944, y: 288, width: 448, height: 312))
        XCTAssertTrue(screenFrame.contains(geometry.compactFrame))
        XCTAssertTrue(screenFrame.contains(geometry.expandedFrame))
    }

    func testCompactFrameIsContainedWhenScreenIsNarrowerThanFallbackWidth() {
        let screenFrame = CGRect(x: 240, y: -80, width: 100, height: 100)
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            visibleFrame: screenFrame,
            safeAreaInsets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )

        XCTAssertEqual(geometry.compactFrame.width, 100)
        XCTAssertEqual(geometry.compactFrame.midX, screenFrame.midX)
        XCTAssertEqual(geometry.compactFrame.maxY, screenFrame.maxY)
        XCTAssertTrue(screenFrame.contains(geometry.compactFrame))
    }

    func testAuxiliaryGapBelowMinimumUses120PointCompactWidth() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            safeAreaInsets: NSEdgeInsets(top: 50, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 750, width: 470, height: 50),
            auxiliaryTopRightArea: CGRect(x: 530, y: 750, width: 470, height: 50)
        )

        XCTAssertEqual(geometry.compactFrame.width, 120)
    }

    func testAuxiliaryGapAboveMaximumUses220PointCompactWidth() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            safeAreaInsets: NSEdgeInsets(top: 50, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 750, width: 350, height: 50),
            auxiliaryTopRightArea: CGRect(x: 650, y: 750, width: 350, height: 50)
        )

        XCTAssertEqual(geometry.compactFrame.width, 220)
    }
}
