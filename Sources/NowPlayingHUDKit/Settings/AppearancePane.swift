import SwiftUI

struct AppearancePane: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "Appearance", subtitle: "A small number of genuinely good styles, not a theme editor.")

            SettingsGroup("Style") {
                Picker("Style", selection: $preferences.hudStyle) {
                    ForEach(HUDVisualStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Size", selection: $preferences.hudSize) {
                    ForEach(HUDSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsGroup("Color") {
                Picker("Appearance", selection: $preferences.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Subtle artwork accent", isOn: $preferences.accentFromArtwork)
                    .help("A gentle tint derived from the album art. Never used for text color.")
            }

            SettingsGroup("Motion") {
                Picker("Animation", selection: $preferences.animationPreference) {
                    ForEach(AnimationPreference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .pickerStyle(.menu)
                Text("Reduce Motion in Accessibility settings is always respected, regardless of this setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
