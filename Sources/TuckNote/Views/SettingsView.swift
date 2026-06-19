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
