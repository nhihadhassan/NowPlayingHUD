import SwiftUI

struct AdvancedPane: View {
    @Bindable var preferences: PreferencesStore
    var playback: PlaybackCoordinator

    @State private var spotifyStatus: AutomationStatus = .notDetermined
    @State private var musicStatus: AutomationStatus = .notDetermined
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "Advanced", subtitle: "Automation permission and diagnostics.")

            SettingsGroup("Automation Permission") {
                statusRow(title: "Spotify", status: spotifyStatus)
                statusRow(title: "Apple Music", status: musicStatus)

                HStack(spacing: 10) {
                    Button("Test Spotify Connection", action: testSpotifyConnection)
                        .disabled(isTesting)
                    if isTesting { ProgressView().controlSize(.small) }
                }
                if let testResult {
                    Text(testResult).font(.caption).foregroundStyle(.secondary)
                }
                Text("If denied, enable it in System Settings → Privacy & Security → Automation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Privacy Settings") {
                    AutomationPermissionService.shared.openAutomationSettings()
                }
                .font(.caption)
            }

            if preferences.developerModeEnabled {
                SettingsGroup("Developer") {
                    Text("Developer mode is enabled (NPHDeveloperMode default). Use the Debug menu from the menu bar's context menu to drive mock playback scenarios.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear(perform: refreshStatuses)
    }

    private func refreshStatuses() {
        spotifyStatus = AutomationPermissionService.shared.status(for: .spotify)
        musicStatus = AutomationPermissionService.shared.status(for: .appleMusic)
    }

    /// There's no dedicated "ping" command, so this uses a harmless, functionally invisible
    /// round trip — setting the volume to its own current value — purely to force a real Apple
    /// Event exchange (and, the first time, the system consent prompt). Goes straight to the
    /// Spotify provider rather than through `playback.perform`'s "active provider" routing, so
    /// this genuinely tests Spotify even if it isn't the currently active player, and reports
    /// what this attempt itself actually returned rather than re-deriving it from a status read.
    private func testSpotifyConnection() {
        let awaitingFirstConsent = spotifyStatus == .notDetermined
        isTesting = true
        testResult = awaitingFirstConsent
            ? "Look for a system dialog asking to control Spotify, then click OK…"
            : nil
        Task {
            let currentVolume = playback.currentSnapshot.track != nil ? playback.currentSnapshot.volume : 50
            let result = await playback.perform(.setVolume(currentVolume), on: .spotify)
            refreshStatuses()
            switch result {
            case .success:
                testResult = "Connected successfully."
            case .failure(.playerNotRunning):
                testResult = "Spotify isn't running — open it and try again."
            case .failure(.automationDenied):
                testResult = "Permission denied — see status above."
            case .failure:
                testResult = "Could not verify a connection — see status above."
            }
            isTesting = false
        }
    }

    @ViewBuilder
    private func statusRow(title: String, status: AutomationStatus) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color(for: status)).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Text(label(for: status)).foregroundStyle(.secondary).font(.caption)
        }
    }

    private func color(for status: AutomationStatus) -> Color {
        switch status {
        case .authorized: return .green
        case .denied: return .red
        case .targetNotRunning: return .gray
        case .notDetermined, .unknown: return .orange
        }
    }

    private func label(for status: AutomationStatus) -> String {
        switch status {
        case .authorized: return "Connected"
        case .denied: return "Denied"
        case .targetNotRunning: return "Not Running"
        case .notDetermined: return "Not Yet Requested"
        case .unknown(let code): return "Unknown (\(code))"
        }
    }
}
