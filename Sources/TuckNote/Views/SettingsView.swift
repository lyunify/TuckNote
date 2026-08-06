import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Picker("Open notch", selection: $settings.triggerMode) {
                Text("Click").tag(TriggerMode.click)
                Text("Hover").tag(TriggerMode.hover)
            }
            .pickerStyle(.segmented)

            Picker("Theme", selection: $settings.themeMode) {
                Text("Light").tag(ThemeMode.light)
                Text("Dark").tag(ThemeMode.dark)
            }
            .pickerStyle(.segmented)

            Toggle("Keep panel pinned", isOn: $settings.isPanelPinned)

            KeyboardShortcuts.Recorder(
                "Toggle TuckNote",
                name: .toggleTuckNote
            )
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
