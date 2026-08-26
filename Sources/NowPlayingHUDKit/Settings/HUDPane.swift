import SwiftUI

struct HUDPane: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "HUD", subtitle: "Where it appears, how long it stays, and what makes it show up.")

            SettingsGroup("Position") {
                Picker("Position", selection: $preferences.hudPosition) {
                    ForEach(HUDPosition.allCases) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .pickerStyle(.menu)

                Picker("Display", selection: $preferences.monitorBehavior) {
                    ForEach(MonitorBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.menu)

                LabeledContent("Edge offset") {
                    Slider(value: $preferences.edgeOffset, in: 0...48, step: 2)
                    Text("\(Int(preferences.edgeOffset)) pt").monospacedDigit().foregroundStyle(.secondary)
                }
            }

            SettingsGroup("Timing") {
                LabeledContent("Display duration") {
                    Slider(value: $preferences.displayDurationSeconds, in: 1...8, step: 0.5)
                    Text(String(format: "%.1f s", preferences.displayDurationSeconds)).monospacedDigit().foregroundStyle(.secondary)
                }
                Toggle("Hover to expand controls", isOn: $preferences.hoverToExpand)
                LabeledContent("Resume dismissal after") {
                    Slider(value: $preferences.hoverDismissDelaySeconds, in: 0.5...4, step: 0.5)
                        .disabled(!preferences.hoverToExpand)
                    Text(String(format: "%.1f s", preferences.hoverDismissDelaySeconds)).monospacedDigit().foregroundStyle(.secondary)
                }
            }

            SettingsGroup("Show On") {
                Toggle("Track change", isOn: $preferences.showOnTrackChange)
                Toggle("Play / resume", isOn: $preferences.showOnPlayResume)
                Toggle("Pause", isOn: $preferences.showOnPause)
                Toggle("Manual playback changes", isOn: $preferences.showOnManualControl)
                    .help("Actions taken through this app itself — the menu bar player or a global shortcut.")
            }
        }
    }
}
