import AppKit
import Foundation
import Observation

/// The HUD's currently-displayed content — separate from `HUDStateMachine`, which only governs
/// *whether* the panel is on screen. This updates on every playback event, significant or not
/// (so e.g. Spotify's phase-2 artwork enrichment refreshes the picture in place even when it
/// doesn't warrant restarting the dismissal timer), and the SwiftUI view binds to it directly.
@MainActor
@Observable
public final class HUDContentModel {
    public var track: Track?
    public var state: PlaybackState = .stopped
    public var reportedPosition: TimeInterval = 0
    public var capturedAt: ContinuousClock.Instant = .now
    public var volume: Int = 0
    public var shuffle: Bool = false
    public var repeatMode: RepeatMode = .off
    public var capabilities: PlayerCapabilities = []

    public var artworkImage: NSImage?
    public var accent: ArtworkAccent?

    /// Drives the SwiftUI entrance/exit transition. Set by `HUDPresentationCoordinator`, never
    /// by the view itself.
    public var isVisible: Bool = false

    /// Mirrors the SwiftUI content's own `.onHover` state, so `HUDRootView`'s layout (compact vs.
    /// expanded) and `HUDPresentationCoordinator`'s dismissal-timer logic agree on one source of
    /// truth. The view writes this directly; the coordinator only reads it.
    public var isHovering: Bool = false

    public init() {}

    public func apply(_ snapshot: PlaybackSnapshot) {
        track = snapshot.track
        state = snapshot.state
        reportedPosition = snapshot.reportedPosition
        capturedAt = snapshot.capturedAt
        volume = snapshot.volume
        shuffle = snapshot.shuffle
        repeatMode = snapshot.repeatMode
        capabilities = snapshot.capabilities
    }

    public var progressEstimator: ProgressEstimator {
        ProgressEstimator(
            reportedPosition: reportedPosition, capturedAt: capturedAt, state: state,
            duration: track?.duration.timeInterval ?? 0
        )
    }
}
