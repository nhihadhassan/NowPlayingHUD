import SwiftUI

struct ControlsPane: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "Controls", subtitle: "What clicking the HUD does.")

            SettingsGroup("Click Action") {
                Picker("Clicking artwork or track info", selection: $preferences.primaryClickAction) {
                    ForEach(HUDClickAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .pickerStyle(.menu)
            }

            SettingsGroup("Right-Click") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([
                        "Open in Spotify", "Copy Track Link", "Copy “Track — Artist”",
                        "Show Player", "Disable Automatic HUD Temporarily", "Dismiss"
                    ], id: \.self) { item in
                        Label(item, systemImage: "checkmark").labelStyle(.titleOnly)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Right-clicking the HUD always shows this menu — it isn't configurable, to keep things predictable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
