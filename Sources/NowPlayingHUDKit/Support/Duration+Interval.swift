import Foundation

extension Duration {
    /// Converts to a `TimeInterval` (seconds as `Double`). `Duration`'s own components are
    /// (seconds: Int64, attoseconds: Int64), so this loses no meaningful precision for anything
    /// we use it for (track lengths, elapsed time deltas).
    public var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }

    /// Constructs a `Duration` from a `TimeInterval` (seconds).
    public init(timeInterval: TimeInterval) {
        self = .seconds(timeInterval)
    }
}

extension ContinuousClock.Instant {
    /// The elapsed `TimeInterval` from `other` to `self` (i.e. `self - other`), matching the
    /// sign convention of `Date.timeIntervalSince(_:)`. `Duration` is a signed type, so this is
    /// negative when `other` is later than `self`.
    public func timeIntervalSince(_ other: ContinuousClock.Instant) -> TimeInterval {
        other.duration(to: self).timeInterval
    }
}
