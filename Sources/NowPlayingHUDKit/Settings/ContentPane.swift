import SwiftUI

struct ContentPane: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "Content", subtitle: "What information the HUD shows.")

            SettingsGroup("Fields") {
                Toggle("Album art", isOn: $preferences.showAlbumArt)
                Toggle("Title", isOn: $preferences.showTitle)
                Toggle("Artist", isOn: $preferences.showArtist)
                Toggle("Album", isOn: $preferences.showAlbum)
                Toggle("Progress bar", isOn: $preferences.showProgress)
                Toggle("Elapsed / remaining time", isOn: $preferences.showTime)
                    .help("Shown in the expanded (hover) state.")
                Toggle("Playback controls", isOn: $preferences.showControls)
                    .help("Transport, scrubber, volume, shuffle, and repeat in the expanded state.")
            }
        }
    }
}
