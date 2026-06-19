import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleTuckNote = Self(
        "toggleTuckNote",
        default: .init(.space, modifiers: [.option])
    )
}

@MainActor
protocol GlobalShortcutRegistering: AnyObject {
    func registerKeyUpHandler(_ handler: @escaping () -> Void)
    func removeKeyUpHandler()
}

@MainActor
final class KeyboardShortcutsRegistrar: GlobalShortcutRegistering {
    func registerKeyUpHandler(_ handler: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .toggleTuckNote, action: handler)
    }

    func removeKeyUpHandler() {
        KeyboardShortcuts.removeHandler(for: .toggleTuckNote)
    }
}

@MainActor
public final class GlobalShortcutService {
    private let registrar: any GlobalShortcutRegistering
    private var isStarted = false

    init(registrar: any GlobalShortcutRegistering = KeyboardShortcutsRegistrar()) {
        self.registrar = registrar
    }

    public func start(onToggle: @escaping () -> Void) {
        if isStarted {
            registrar.removeKeyUpHandler()
        }
        registrar.registerKeyUpHandler(onToggle)
        isStarted = true
    }

    public func stop() {
        guard isStarted else { return }
        registrar.removeKeyUpHandler()
        isStarted = false
    }
}
