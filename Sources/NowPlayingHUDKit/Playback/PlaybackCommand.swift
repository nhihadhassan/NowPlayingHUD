import Foundation

/// A user-initiated transport/control action, player-agnostic. `PlaybackCoordinator` routes
/// these to whichever `PlaybackProvider` is currently active.
public enum PlaybackCommand: Sendable, Equatable {
    case play
    case pause
    case playPause
    /// Matches Spotify/Apple Music's own "previous" semantics: restart the current track if
    /// sufficiently far into it, otherwise go to the actual previous track. Implemented by each
    /// provider (see `SpotifyPlaybackProvider.previous()`), not simulated here.
    case previous
    case next
    /// Absolute seek target in seconds.
    case seek(to: TimeInterval)
    /// Absolute volume, 0...100.
    case setVolume(Int)
    case setShuffle(Bool)
    case setRepeatMode(RepeatMode)
}

public enum PlaybackError: Error, Sendable, Equatable {
    /// The target application isn't running.
    case playerNotRunning
    /// Automation permission for this app has not been granted (or was denied).
    case automationDenied
    /// The Apple Event round trip did not complete before the deadline.
    case timedOut
    /// The command isn't supported by this provider's `PlayerCapabilities`.
    case unsupported
    /// Any other scripting failure, carrying the raw OSStatus/NSError code for diagnostics.
    case underlying(code: Int, message: String)
}

/// Events a `PlaybackProvider` publishes on its `events` stream. `PlaybackCoordinator` consumes
/// these; nothing about window/UI lifecycle lives at this layer.
public enum ProviderEvent: Sendable, Equatable {
    /// The provider's application launched (via `NSWorkspace` observation).
    case applicationLaunched
    /// The provider's application quit.
    case applicationTerminated
    /// A distributed notification signaled a state change; `snapshot` is the freshly-fetched
    /// (or, if Automation is denied, notification-derived) state.
    case snapshotUpdated(PlaybackSnapshot)
}
