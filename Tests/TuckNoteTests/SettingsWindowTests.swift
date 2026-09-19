import AppKit
import XCTest
@testable import TuckNote

@MainActor
final class SettingsWindowTests: XCTestCase {
    func testSettingsReusesAndShowsAKeyEligibleWindowEveryTime() throws {
        _ = NSApplication.shared
        let controller = SettingsWindowController(settings: AppSettings(defaults: UserDefaults(suiteName: "TuckNote.SettingsWindowTests")!))
        controller.present()
        let first = try XCTUnwrap(controller.window)
        defer { first.close() }
        XCTAssertTrue(first.isVisible)
        // The command-line XCTest host cannot activate as a foreground app.
        XCTAssertTrue(first.canBecomeKey)
        first.close()
        controller.present()
        XCTAssertTrue(controller.window === first)
        XCTAssertTrue(first.isVisible)
        XCTAssertTrue(first.canBecomeKey)
    }
}
