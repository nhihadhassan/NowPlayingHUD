import AppKit
import SwiftUI

/// A real macOS Settings window — a standard titled `NSWindow` hosting SwiftUI content, not a
/// bespoke "preferences-looking" panel. Single-instance: calling `show()` again just brings the
/// existing window forward instead of creating a second one.
@MainActor
public final class SettingsWindowController: NSWindowController {
    public init(
        preferences: PreferencesStore, playback: PlaybackCoordinator, hudCoordinator: HUDPresentationCoordinator,
        shortcutController: GlobalShortcutController
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(Branding.appName) Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(
                preferences: preferences, playback: playback, hudCoordinator: hudCoordinator,
                shortcutController: shortcutController
            )
        )
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
