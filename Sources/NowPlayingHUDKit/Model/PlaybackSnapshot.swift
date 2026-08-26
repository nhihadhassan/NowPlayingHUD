import Foundation

/// A complete, immutable snapshot of a player's state at one instant, as reported by an
/// Apple Event round trip (or, in degraded mode, a distributed-notification payload).
///
/// `capturedAt` uses `ContinuousClock` rather than `Date`/`wall clock` deliberately: it does not
/// jump on system-clock changes and keeps counting through display sleep, so extrapolating
/// playback position from it (`ProgressEstimator`) stays correct across those events. It does
/// pause across full system sleep, which is fine — `AppEnvironment` resynchronizes on wake.
public struct PlaybackSnapshot: Sendable, Equatable {
    public let track: Track?
    public let state: PlaybackState
    /// The position (in seconds) the player itself reported, at `capturedAt`.
    public let reportedPosition: TimeInterval
    public let capturedAt: ContinuousClock.Instant
    /// 0...100, matching both Spotify's and Apple Music's scripting range.
    public let volume: Int
    public let shuffle: Bool
    public let repeatMode: RepeatMode
    public let capabilities: PlayerCapabilities

    public init(
        track: Track?,
        state: PlaybackState,
        reportedPosition: TimeInterval,
        capturedAt: ContinuousClock.Instant,
        volume: Int,
        shuffle: Bool,
        repeatMode: RepeatMode,
        capabilities: PlayerCapabilities
    ) {
        self.track = track
        self.state = state
        self.reportedPosition = reportedPosition
        self.capturedAt = capturedAt
        self.volume = volume
        self.shuffle = shuffle
        self.repeatMode = repeatMode
        self.capabilities = capabilities
    }

    public static func == (lhs: PlaybackSnapshot, rhs: PlaybackSnapshot) -> Bool {
        lhs.track == rhs.track
            && lhs.state == rhs.state
            && lhs.reportedPosition == rhs.reportedPosition
            && lhs.capturedAt == rhs.capturedAt
            && lhs.volume == rhs.volume
            && lhs.shuffle == rhs.shuffle
            && lhs.repeatMode == rhs.repeatMode
            && lhs.capabilities == rhs.capabilities
    }

    /// A snapshot representing "no player available" (Spotify/Music not running, or not yet queried).
    public static func idle(capabilities: PlayerCapabilities = []) -> PlaybackSnapshot {
        PlaybackSnapshot(
            track: nil,
            state: .stopped,
            reportedPosition: 0,
            capturedAt: .now,
            volume: 0,
            shuffle: false,
            repeatMode: .off,
            capabilities: capabilities
        )
    }

    /// Whether this snapshot and another represent the *same playback event* for deduplication
    /// purposes — same track, same play/pause state, and no meaningful seek. Spotify's
    /// `PlaybackStateChanged` notification is known to fire more than once for a single real
    /// change; `PlaybackCoordinator` uses this to collapse those into one HUD presentation.
    public func isSignificantChange(from previous: PlaybackSnapshot?, seekThreshold: TimeInterval = 1.5) -> Bool {
        guard let previous else { return true }
        if previous.track?.id != track?.id { return true }
        if previous.state != state { return true }
        // A same-track, same-state update is only "significant" if the position jumped further
        // than normal elapsed-time drift would explain, i.e. an explicit seek.
        let elapsed = capturedAt.timeIntervalSince(previous.capturedAt)
        let expected = previous.reportedPosition + elapsed
        if abs(reportedPosition - expected) > seekThreshold { return true }
        return false
    }
}
