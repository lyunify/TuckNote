import XCTest
import TuckNote

@MainActor
final class GlobalShortcutPublicAPITests: XCTestCase {
    func testServiceTypeIsPublic() {
        XCTAssertNotNil(GlobalShortcutService.self)
    }

    private func compilePublicLifecycleMethods(on service: GlobalShortcutService) {
        service.start {}
        service.stop()
    }
}
