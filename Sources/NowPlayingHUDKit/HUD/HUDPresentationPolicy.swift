import Foundation

/// What kind of change a playback event represents, for the "show on track change / play /
/// pause / manual control" preferences to key off of.
public enum PlaybackChangeKind: Sendable, Equatable {
    case trackChanged
    case playResumed
    case paused
    /// The user triggered this through this app's own UI (menu bar popover, HUD controls, or a
    /// global shortcut) — always worth a confirmation HUD if `showOnManualControl` is on,
    /// regardless of the other show-on-* toggles.
    case manualControl
    case other
}

/// Pure decision logic for "should this particular change actually present/update the HUD",
/// separated from `HUDPresentationCoordinator` so it's directly unit-testable without any
/// AppKit/timer/window machinery.
public enum HUDPresentationPolicy {
    public static func shouldPresent(
        isSignificant: Bool,
        changeKind: PlaybackChangeKind,
        automaticHUDEnabled: Bool,
        temporarilyDisabled: Bool,
        showOnTrackChange: Bool,
        showOnPlayResume: Bool,
        showOnPause: Bool,
        showOnManualControl: Bool,
        isPlayerFrontmost: Bool,
        hideWhenPlayerFrontmost: Bool
    ) -> Bool {
        guard isSignificant, automaticHUDEnabled, !temporarilyDisabled else { return false }

        // A manual action taken through this app's own UI always wins over "hide when
        // frontmost" — if the user just clicked Next in the menu bar popover, showing that it
        // worked is the point, even if the player itself happens to be the frontmost app.
        if changeKind == .manualControl {
            return showOnManualControl
        }
        if isPlayerFrontmost && hideWhenPlayerFrontmost {
            return false
        }
        switch changeKind {
        case .trackChanged: return showOnTrackChange
        case .playResumed: return showOnPlayResume
        case .paused: return showOnPause
        case .manualControl: return showOnManualControl // unreachable (handled above); exhaustive.
        case .other: return showOnTrackChange
        }
    }

    /// Classifies a change from the previous to the new snapshot. Track identity takes priority
    /// over a simultaneous state change (a new track starting mid-`playing` is a track change,
    /// not a "resume").
    public static func classify(previous: PlaybackSnapshot?, new: PlaybackSnapshot) -> PlaybackChangeKind {
        guard let previous else { return .trackChanged }
        if previous.track?.id != new.track?.id { return .trackChanged }
        if previous.state != new.state {
            if new.state == .playing { return .playResumed }
            if new.state == .paused { return .paused }
        }
        return .other
    }
}
