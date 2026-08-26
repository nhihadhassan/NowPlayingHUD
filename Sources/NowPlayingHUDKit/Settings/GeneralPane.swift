import SwiftUI

struct GeneralPane: View {
    @Bindable var preferences: PreferencesStore
    var playback: PlaybackCoordinator

    @State private var launchAtLoginStatus: LaunchAtLoginController.Status = .disabled
    @State private var launchAtLoginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "General", subtitle: "The essentials — how NowPlayingHUD starts up and behaves day to day.")

            SettingsGroup("Playback") {
                Toggle("Enable automatic HUD", isOn: $preferences.automaticHUDEnabled)
                Picker("Player", selection: $preferences.playerSelectionMode) {
                    ForEach(PlayerSelectionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .help("Automatic prefers whichever player is currently playing.")
            }

            SettingsGroup("Menu Bar") {
                Toggle("Show menu bar item", isOn: $preferences.showMenuBarItem)
                Picker("Display", selection: $preferences.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!preferences.showMenuBarItem)
            }

            SettingsGroup("Full Screen & Focus") {
                Toggle("Show over full-screen apps", isOn: $preferences.showOverFullScreenApps)
                Toggle("Hide when player is frontmost", isOn: $preferences.hideWhenPlayerFrontmost)
            }

            SettingsGroup("Startup") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                if launchAtLoginStatus == .requiresApproval {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Approval needed in System Settings → General → Login Items.")
                            .font(.caption)
                        Button("Open Settings") { LaunchAtLoginController.openLoginItemsSettings() }
                            .font(.caption)
                    }
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .onAppear { launchAtLoginStatus = LaunchAtLoginController.status }
        .onChange(of: preferences.playerSelectionMode) { _, newValue in
            playback.selectionMode = newValue
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval },
            set: { newValue in
                switch LaunchAtLoginController.setEnabled(newValue) {
                case .success:
                    launchAtLoginError = nil
                case .failure(let error):
                    launchAtLoginError = error.localizedDescription
                }
                launchAtLoginStatus = LaunchAtLoginController.status
            }
        )
    }
}

/// A section header used throughout Settings: a bold title plus a one-line explanation, matching
/// the tone of a real macOS preference pane rather than a bare form.
struct PaneHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

/// A titled group of related controls with a subtle card background — the closest SwiftUI
/// equivalent to `NSBox`-grouped preference sections.
struct SettingsGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
