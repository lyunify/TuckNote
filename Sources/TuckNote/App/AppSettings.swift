import Combine
import Foundation

enum PanelTriggerMode: String, CaseIterable, Identifiable {
    case click
    case hover

    var id: Self { self }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let triggerMode = "panelTriggerMode"
    }

    private let defaults: UserDefaults

    @Published var triggerMode: PanelTriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: Key.triggerMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        triggerMode = defaults.string(forKey: Key.triggerMode)
            .flatMap(PanelTriggerMode.init(rawValue:)) ?? .click
    }
}
