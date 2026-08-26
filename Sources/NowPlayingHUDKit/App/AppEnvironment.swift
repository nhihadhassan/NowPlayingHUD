import AppKit
import Foundation

/// The composition root: creates every long-lived object once and wires them together. Kept
/// intentionally simple — a handful of `let`/`lazy var` properties and one `start()` method,
/// not a dependency-injection framework.
@MainActor
public final class AppEnvironment {
    public let preferences = PreferencesStore()
    private let artworkCache = ArtworkCache()
    private lazy var artworkService = ArtworkService(cache: artworkCache)

    /// Non-nil only when developer mode is on (`NPHDeveloperMode` default) — see
    /// `DebugScenarios`. Real Spotify/Apple Music providers are swapped out for a single mock at
    /// launch in that case, rather than live-toggled, so there's no risk of two providers ever
    /// registering under the same `PlayerIdentifier`.
    public let debugMockProvider: MockPlaybackProvider?

    public lazy var playbackCoordinator: PlaybackCoordinator = {
        if let debugMockProvider {
            return PlaybackCoordinator(providers: [debugMockProvider])
        }
        return PlaybackCoordinator(providers: [SpotifyPlaybackProvider(), AppleMusicPlaybackProvider()])
    }()

    public lazy var hudCoordinator = HUDPresentationCoordinator(
        preferences: preferences, playback: playbackCoordinator, artworkService: artworkService
    )

    public let shortcutController = GlobalShortcutController()

    private lazy var settingsWindowController = SettingsWindowController(
        preferences: preferences, playback: playbackCoordinator, hudCoordinator: hudCoordinator,
        shortcutController: shortcutController
    )

    private lazy var menuBarController = MenuBarController(
        preferences: preferences, playback: playbackCoordinator, hudCoordinator: hudCoordinator,
        debugMockProvider: debugMockProvider,
        openSettings: { [weak self] in self?.showSettings() },
        openAbout: { [weak self] in self?.showSettings() }
    )

    public init() {
        debugMockProvider = preferences.developerModeEnabled ? MockPlaybackProvider(identifier: .spotify) : nil
    }

    public func start() {
        playbackCoordinator.selectionMode = preferences.playerSelectionMode
        playbackCoordinator.start()
        hudCoordinator.start()
        menuBarController.start()
        setUpShortcuts()
        showFirstLaunchWelcomeIfNeeded()
    }

    public func stop() {
        menuBarController.stop()
        hudCoordinator.stop()
        playbackCoordinator.stop()
        shortcutController.stop()
    }

    public func showSettings() {
        settingsWindowController.show()
    }

    // MARK: - Global shortcuts

    private func setUpShortcuts() {
        shortcutController.start { [weak self] action in
            Task { @MainActor in self?.handle(action) }
        }
        for (action, combo) in preferences.shortcutBindings {
            shortcutController.setCombo(combo, for: action)
        }
    }

    private func handle(_ shortcutAction: ShortcutAction) {
        let content = hudCoordinator.contentModel
        switch shortcutAction {
        case .toggleHUD:
            hudCoordinator.toggleVisibility()
        case .playPause:
            hudCoordinator.perform(.playPause)
        case .next:
            hudCoordinator.perform(.next)
        case .previous:
            hudCoordinator.perform(.previous)
        case .volumeUp:
            hudCoordinator.perform(.setVolume(min(100, content.volume + 10)))
        case .volumeDown:
            hudCoordinator.perform(.setVolume(max(0, content.volume - 10)))
        case .seekForward:
            let position = content.progressEstimator.position()
            hudCoordinator.perform(.seek(to: min(content.progressEstimator.duration, position + 15)))
        case .seekBackward:
            let position = content.progressEstimator.position()
            hudCoordinator.perform(.seek(to: max(0, position - 15)))
        }
    }

    // MARK: - First launch

    private func showFirstLaunchWelcomeIfNeeded() {
        let key = "hasShownWelcome"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let alert = NSAlert()
        alert.messageText = "Welcome to \(Branding.appName)"
        alert.informativeText = """
        \(Branding.appName) shows a brief, elegant popup whenever your Spotify (or Apple Music) \
        track changes — nothing else. It lives in the menu bar; there's no Dock icon.

        The first time you use playback controls, macOS may ask permission for \
        \(Branding.appName) to control Spotify. This is required for track info and controls, \
        and everything stays entirely on this Mac — no accounts, no analytics, no remote servers.

        Click the menu bar icon any time for the full player, or open Settings to customize \
        position, appearance, and shortcuts.
        """
        alert.addButton(withTitle: "Get Started")
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
