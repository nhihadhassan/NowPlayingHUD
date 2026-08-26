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
    /// round trip — setting the volume to its own current value — purely to force an Apple
    /// Event exchange (and, the first time, the system consent prompt) and then re-reads status.
    private func testSpotifyConnection() {
        isTesting = true
        testResult = nil
        Task {
            _ = await playback.perform(.setVolume(playback.currentSnapshot.volume))
            try? await Task.sleep(for: .seconds(0.3))
            refreshStatuses()
            testResult = spotifyStatus == .authorized
                ? "Connected successfully."
                : "Could not verify a connection — see status above."
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
