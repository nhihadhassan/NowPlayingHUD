import Foundation

/// A local, event-driven source of "what's playing" for one media application.
///
/// Implementations must be event-driven, not polling: each one subscribes to its application's
/// distributed notification (`com.spotify.client.PlaybackStateChanged` /
/// `com.apple.Music.playerInfo`) and treats it purely as a trigger to fetch one fresh
/// `PlaybackSnapshot`. There is no periodic timer inside a provider.
public protocol PlaybackProvider: AnyObject, Sendable {
    var identifier: PlayerIdentifier { get }

    /// Whether the application is installed on this Mac at all (used to decide whether to offer
    /// it as a `player` choice in Settings, and for the menu bar's empty state).
    var isInstalled: Bool { get }

    /// Whether the application is currently running. Backed by `NSWorkspace`/notification
    /// observation, never by spawning a process to check.
    var isRunning: Bool { get }

    /// A live stream of state-change and lifecycle events. Cold on creation; call `start()` to
    /// begin observing. The stream never finishes on its own.
    var events: AsyncStream<ProviderEvent> { get }

    /// Begins observing distributed notifications and `NSWorkspace` launch/terminate events.
    /// Idempotent.
    func start()

    /// Stops all observation. Idempotent. Safe to call during app teardown.
    func stop()

    /// Performs one Apple Event round trip to fetch the complete current state. Used on startup
    /// (Spotify may already be playing when we launch) and as a low-frequency recovery path —
    /// never on a fast repeating timer.
    func refreshSnapshot() async -> Result<PlaybackSnapshot, PlaybackError>

    /// Executes a transport/control command against the live application.
    func perform(_ command: PlaybackCommand) async -> Result<Void, PlaybackError>
}
