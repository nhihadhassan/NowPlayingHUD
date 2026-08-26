import SwiftUI

struct AboutPane: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Branding.appName).font(.title2.bold())
                    Text("Version \(version)").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            SettingsGroup("Privacy") {
                Label("No analytics, telemetry, or crash reporting.", systemImage: "checkmark.shield")
                Label("No account, no remote database.", systemImage: "checkmark.shield")
                Label("Everything runs locally against the Spotify/Apple Music app already on this Mac.", systemImage: "checkmark.shield")
                Label("Artwork is fetched directly from Spotify's own CDN — the only network traffic this app makes.", systemImage: "checkmark.shield")
            }
            .font(.callout)

            SettingsGroup("About") {
                Text("A small, native utility that shows a Now Playing HUD when your track changes — built with SwiftUI, AppKit, and Apple's own scripting interfaces for Spotify and Apple Music. No Electron, no webview, no backend.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
