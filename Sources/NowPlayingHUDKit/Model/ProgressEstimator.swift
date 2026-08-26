import Foundation

/// Extrapolates a track's current playback position from the last known snapshot, without ever
/// re-querying the player. This is the core of the "no 1-second polling" requirement: once we
/// have `(reportedPosition, capturedAt, state)`, the position at any later instant is pure math.
///
/// A fresh snapshot (new track, play, pause, or a detected seek) simply replaces the estimator's
/// input; nothing needs to be "reset" beyond that, so this type carries no mutable state itself.
public struct ProgressEstimator: Sendable, Equatable {
    public let reportedPosition: TimeInterval
    public let capturedAt: ContinuousClock.Instant
    public let state: PlaybackState
    public let duration: TimeInterval

    public init(reportedPosition: TimeInterval, capturedAt: ContinuousClock.Instant, state: PlaybackState, duration: TimeInterval) {
        self.reportedPosition = reportedPosition
        self.capturedAt = capturedAt
        self.state = state
        self.duration = duration
    }

    public init(snapshot: PlaybackSnapshot) {
        self.reportedPosition = snapshot.reportedPosition
        self.capturedAt = snapshot.capturedAt
        self.state = snapshot.state
        self.duration = snapshot.track?.duration.timeInterval ?? 0
    }

    /// The extrapolated position at `instant`, clamped to `0...duration`.
    /// While paused or stopped, position never advances regardless of elapsed wall time.
    public func position(at instant: ContinuousClock.Instant = .now) -> TimeInterval {
        guard state == .playing else {
            return reportedPosition.clamped(to: 0...max(duration, 0))
        }
        let elapsed = instant.timeIntervalSince(capturedAt)
        let projected = reportedPosition + max(elapsed, 0)
        guard duration > 0 else { return max(projected, 0) }
        return projected.clamped(to: 0...duration)
    }

    /// Fractional progress in `0...1`, safe against a zero or unknown duration.
    public func fractionComplete(at instant: ContinuousClock.Instant = .now) -> Double {
        guard duration > 0 else { return 0 }
        return (position(at: instant) / duration).clamped(to: 0...1)
    }

    /// Whether the track has run to completion as of `instant` — useful to stop a repaint timer
    /// slightly before the *next* snapshot naturally arrives from the player.
    public func isFinished(at instant: ContinuousClock.Instant = .now) -> Bool {
        duration > 0 && position(at: instant) >= duration
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
