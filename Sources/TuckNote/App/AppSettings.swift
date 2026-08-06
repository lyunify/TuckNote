import Combine
import Foundation

enum TriggerMode: String, Codable, CaseIterable, Identifiable {
    case click
    case hover

    var id: Self { self }
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case light
    case dark

    var id: Self { self }

    var toggled: Self {
        switch self {
        case .light:
            .dark
        case .dark:
            .light
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let triggerMode = "panelTriggerMode"
        static let themeMode = "themeMode"
        static let isPanelPinned = "isPanelPinned"
    }

    private let defaults: UserDefaults

    @Published var triggerMode: TriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: Key.triggerMode) }
    }
    @Published var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Key.themeMode) }
    }
    @Published var isPanelPinned: Bool {
        didSet { defaults.set(isPanelPinned, forKey: Key.isPanelPinned) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        triggerMode = defaults.string(forKey: Key.triggerMode)
            .flatMap(TriggerMode.init(rawValue:)) ?? .click
        themeMode = defaults.string(forKey: Key.themeMode)
            .flatMap(ThemeMode.init(rawValue:)) ?? .light
        isPanelPinned = defaults.bool(forKey: Key.isPanelPinned)
    }

    func toggleTheme() {
        themeMode = themeMode.toggled
    }
}
