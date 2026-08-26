import AppKit

/// The floating HUD window. Configured to behave like a system HUD, not an ordinary app window:
///
/// - `.borderless, .nonactivatingPanel`: no titlebar/chrome, and — critically — clicking it never
///   activates this app or steals focus from whatever the user is currently working in.
/// - `level = .statusBar`: floats above regular windows without reaching for the highest
///   possible window level; this is meant to read as a system HUD, not to sit maliciously above
///   everything on screen.
/// - `ignoresMouseEvents = true` by default: the compact, automatically-appearing HUD is
///   click-through, so it never steals a click meant for whatever's underneath it. It only
///   becomes interactive when `setInteractive(true)` is called, which
///   `HUDPresentationCoordinator` does the moment a global mouse-moved monitor detects the
///   pointer has entered the panel's on-screen frame (see that type for why a global monitor is
///   necessary here: a window with `ignoresMouseEvents = true` receives no mouse events of its
///   own, so there is nothing for a local monitor or `NSTrackingArea` to observe).
/// - `orderFrontRegardless()` (used by the coordinator, never `makeKeyAndOrderFront`): the panel
///   is shown without ever making itself key or main, so it cannot appear in Cmd-Tab or steal
///   the currently-active application.
public final class HUDPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // the SwiftUI content draws its own, appearance-correct shadow
        animationBehavior = .none // animation is driven explicitly by HUDPresentationCoordinator
        level = .statusBar
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        collectionBehavior = Self.collectionBehavior(showOverFullScreenApps: true)
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public func setInteractive(_ interactive: Bool) {
        ignoresMouseEvents = !interactive
    }

    /// Recomputed whenever "Show over full-screen apps" changes in Settings.
    ///
    /// `.canJoinAllSpaces` and `.fullScreenAuxiliary` let the panel follow the user across their
    /// own Spaces and their own full-screen windows; `.canJoinAllApplications` (macOS 13+) is the
    /// additional flag needed to appear over a *different* app's full-screen window (a full-screen
    /// video in Safari, a full-screen Keynote presentation, etc.) — added only when the user has
    /// opted in, since showing over another app's full-screen content is the more assertive
    /// behavior. `.transient` keeps the panel out of Mission Control; `.ignoresCycle` keeps it out
    /// of this app's own window-cycling (Cmd-`). These are deliberately not combined with their
    /// mutually-exclusive counterparts (`.moveToActiveSpace`, `.fullScreenPrimary`/`.fullScreenNone`).
    public static func collectionBehavior(showOverFullScreenApps: Bool) -> NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        if showOverFullScreenApps {
            behavior.insert(.canJoinAllApplications)
        }
        return behavior
    }

    public func updateCollectionBehavior(showOverFullScreenApps: Bool) {
        collectionBehavior = Self.collectionBehavior(showOverFullScreenApps: showOverFullScreenApps)
    }
}
