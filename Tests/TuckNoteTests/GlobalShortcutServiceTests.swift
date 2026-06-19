import XCTest
@testable import TuckNote

@MainActor
final class GlobalShortcutServiceTests: XCTestCase {
    func testStartRegistersKeyUpHandlerThatToggles() {
        let registrar = ShortcutRegistrarSpy()
        let service = GlobalShortcutService(registrar: registrar)
        var toggleCount = 0

        service.start { toggleCount += 1 }
        registrar.fireKeyUp()

        XCTAssertEqual(registrar.registerCount, 1)
        XCTAssertEqual(toggleCount, 1)
    }

    func testStopRemovesHandler() {
        let registrar = ShortcutRegistrarSpy()
        let service = GlobalShortcutService(registrar: registrar)
        var toggleCount = 0
        service.start { toggleCount += 1 }

        service.stop()
        registrar.fireKeyUp()

        XCTAssertEqual(registrar.removeCount, 1)
        XCTAssertEqual(toggleCount, 0)
    }

    func testStartingAgainReplacesPreviousHandler() {
        let registrar = ShortcutRegistrarSpy()
        let service = GlobalShortcutService(registrar: registrar)
        var firstToggleCount = 0
        var secondToggleCount = 0
        service.start { firstToggleCount += 1 }

        service.start { secondToggleCount += 1 }
        registrar.fireKeyUp()

        XCTAssertEqual(registrar.registerCount, 2)
        XCTAssertEqual(registrar.removeCount, 1)
        XCTAssertEqual(firstToggleCount, 0)
        XCTAssertEqual(secondToggleCount, 1)
    }
}

@MainActor
private final class ShortcutRegistrarSpy: GlobalShortcutRegistering {
    private var handler: (() -> Void)?
    private(set) var registerCount = 0
    private(set) var removeCount = 0

    func registerKeyUpHandler(_ handler: @escaping () -> Void) {
        registerCount += 1
        self.handler = handler
    }

    func removeKeyUpHandler() {
        removeCount += 1
        handler = nil
    }

    func fireKeyUp() {
        handler?()
    }
}
