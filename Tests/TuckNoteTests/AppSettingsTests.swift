import Foundation
import XCTest
@testable import TuckNote

@MainActor
final class AppSettingsTests: XCTestCase {
    func testDefaultsToClickTriggerMode() {
        let defaults = makeDefaults()

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.triggerMode, .click)
    }

    func testPersistsTriggerMode() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.triggerMode = .hover

        XCTAssertEqual(AppSettings(defaults: defaults).triggerMode, .hover)
    }

    func testTriggerModeIsStringCodable() throws {
        let mode: TriggerMode = .hover

        let data = try JSONEncoder().encode(mode)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"hover\"")
        XCTAssertEqual(try JSONDecoder().decode(TriggerMode.self, from: data), .hover)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
