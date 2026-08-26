import AppKit
import SwiftUI

/// Owns the `NSStatusItem` and its popover — the app's primary home, per "the application should
/// primarily live in the menu bar rather than the Dock." Uses `NSStatusItem`/`NSPopover`
/// directly rather than SwiftUI's `MenuBarExtra` for more control over left-vs-right-click
/// routing and the custom title content (`StatusItemContentView`) the display-mode settings need.
@MainActor
public final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let preferences: PreferencesStore
    private let playback: PlaybackCoordinator
    private let hudCoordinator: HUDPresentationCoordinator
    private let openSettings: () -> Void
    private let openAbout: () -> Void

    private var eventTask: Task<Void, Never>?
    private var titleHostingView: NSHostingView<StatusItemContentView>?

    public init(
        preferences: PreferencesStore, playback: PlaybackCoordinator, hudCoordinator: HUDPresentationCoordinator,
        openSettings: @escaping () -> Void, openAbout: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.playback = playback
        self.hudCoordinator = hudCoordinator
        self.openSettings = openSettings
        self.openAbout = openAbout
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        hudCoordinator.onShowMiniPlayerRequested = { [weak self] in self?.openPopover() }
        configurePopover()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 1) // height determined by SwiftUI's fitting size
        popover.contentViewController = NSHostingController(
            rootView: MiniPlayerView(
                content: hudCoordinator.contentModel, interactor: hudCoordinator,
                isPlayerRunning: playback.anyProviderRunning,
                onOpenSettings: { [weak self] in self?.popover.performClose(nil); self?.openSettings() },
                onLaunchPlayer: { [weak self] in self?.launchActivePlayer() }
            )
        )
    }

    public func start() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        applyDisplayMode()

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.playback.significantEvents {
                self.applyDisplayMode()
                self.refreshPopoverContent()
            }
        }
    }

    public func stop() {
        eventTask?.cancel()
    }

    // MARK: - Status item appearance

    /// Called whenever the display-mode preference changes, in addition to every playback event.
    public func applyDisplayMode() {
        guard let button = statusItem.button else { return }
        let snapshot = playback.currentSnapshot
        let isPlaying = snapshot.state == .playing

        if preferences.menuBarDisplayMode == .iconOnly {
            titleHostingView?.removeFromSuperview()
            titleHostingView = nil
            button.image = NSImage(
                systemSymbolName: isPlaying ? "music.note" : "music.note",
                accessibilityDescription: "NowPlayingHUD"
            )
            button.image?.isTemplate = true
            button.title = ""
        } else {
            button.image = nil
            button.title = ""
            let rootView = StatusItemContentView(mode: preferences.menuBarDisplayMode, track: snapshot.track, isPlaying: isPlaying)
            if let existing = titleHostingView {
                existing.rootView = rootView
            } else {
                let hostingView = NSHostingView(rootView: rootView)
                hostingView.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(hostingView)
                NSLayoutConstraint.activate([
                    hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                    hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
                    hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4)
                ])
                titleHostingView = hostingView
            }
            // Status items size themselves from `statusItem.length`; a custom title view needs an
            // explicit width based on its fitting size (SwiftUI content isn't consulted otherwise).
            let fittingWidth = titleHostingView?.fittingSize.width ?? 60
            statusItem.length = max(28, fittingWidth + 8)
        }
    }

    private func refreshPopoverContent() {
        (popover.contentViewController as? NSHostingController<MiniPlayerView>)?.rootView = MiniPlayerView(
            content: hudCoordinator.contentModel, interactor: hudCoordinator,
            isPlayerRunning: playback.anyProviderRunning,
            onOpenSettings: { [weak self] in self?.popover.performClose(nil); self?.openSettings() },
            onLaunchPlayer: { [weak self] in self?.launchActivePlayer() }
        )
    }

    // MARK: - Click handling

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            presentContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        refreshPopoverContent()
        if let hostingController = popover.contentViewController as? NSHostingController<MiniPlayerView> {
            popover.contentSize = hostingController.view.fittingSize
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func presentContextMenu() {
        let menu = NSMenu()

        let showHUD = NSMenuItem(title: "Show HUD", action: #selector(showHUDAction), keyEquivalent: "")
        showHUD.target = self
        menu.addItem(showHUD)

        let toggleEnabled = NSMenuItem(
            title: preferences.automaticHUDEnabled ? "Disable Automatic HUD" : "Enable Automatic HUD",
            action: #selector(toggleAutomaticHUDAction), keyEquivalent: ""
        )
        toggleEnabled.target = self
        menu.addItem(toggleEnabled)

        menu.addItem(.separator())

        let launchTitle = "Launch \((playback.activeProvider ?? .spotify).displayName)"
        let launch = NSMenuItem(title: launchTitle, action: #selector(launchPlayerAction), keyEquivalent: "")
        launch.target = self
        launch.isEnabled = !playback.anyProviderRunning
        menu.addItem(launch)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About NowPlayingHUD", action: #selector(openAboutAction), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit NowPlayingHUD", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Detach immediately after: keeps left-click routed through `statusItemClicked` rather
        // than always popping this menu (an `NSStatusItem` with a non-nil `menu` intercepts
        // *all* clicks, left included).
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    // MARK: - Menu actions

    @objc private func showHUDAction() { hudCoordinator.showManually() }

    @objc private func toggleAutomaticHUDAction() {
        let newValue = !preferences.automaticHUDEnabled
        preferences.automaticHUDEnabled = newValue
        hudCoordinator.setAutomaticHUDEnabled(newValue)
    }

    @objc private func launchPlayerAction() { launchActivePlayer() }
    @objc private func openSettingsAction() { openSettings() }
    @objc private func openAboutAction() { openAbout() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    private func launchActivePlayer() {
        playback.launchApp(for: playback.activeProvider ?? .spotify)
    }
}
