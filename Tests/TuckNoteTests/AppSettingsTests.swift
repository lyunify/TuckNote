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

    func testDefaultsToLightThemeAndUnlockedPanel() {
        let settings = AppSettings(defaults: makeDefaults())

        XCTAssertEqual(settings.themeMode, .light)
        XCTAssertFalse(settings.isPanelPinned)
    }

    func testPersistsThemeAndPinnedPanel() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.themeMode = .dark
        settings.isPanelPinned = true

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.themeMode, .dark)
        XCTAssertTrue(reloaded.isPanelPinned)
    }

    func testTriggerModeIsStringCodable() throws {
        let mode: TriggerMode = .hover

        let data = try JSONEncoder().encode(mode)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"hover\"")
        XCTAssertEqual(try JSONDecoder().decode(TriggerMode.self, from: data), .hover)
    }

    func testThemeModeIsStringCodable() throws {
        let mode: ThemeMode = .dark

        let data = try JSONEncoder().encode(mode)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"dark\"")
        XCTAssertEqual(try JSONDecoder().decode(ThemeMode.self, from: data), .dark)
    }

    func testToggleThemeSwitchesBetweenLightAndDark() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.toggleTheme()
        XCTAssertEqual(settings.themeMode, .dark)

        settings.toggleTheme()
        XCTAssertEqual(settings.themeMode, .light)
        XCTAssertEqual(AppSettings(defaults: defaults).themeMode, .light)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
