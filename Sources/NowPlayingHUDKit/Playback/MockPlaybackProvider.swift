import Foundation

/// A scripted, in-memory playback source used by the Debug/demo mode (Settings → Advanced →
/// Developer, only visible with `NPHDeveloperMode` set) and by the test suite. Lets both exercise
/// track changes, rapid skipping, missing artwork, very long titles, and varied colors without
/// touching a real player.
public final class MockPlaybackProvider: PlaybackProvider, @unchecked Sendable {
    public let identifier: PlayerIdentifier
    public let events: AsyncStream<ProviderEvent>
    private let continuation: AsyncStream<ProviderEvent>.Continuation

    public private(set) var isRunning: Bool = true
    public let isInstalled: Bool = true

    public init(identifier: PlayerIdentifier = .spotify) {
        self.identifier = identifier
        var continuation: AsyncStream<ProviderEvent>.Continuation!
        events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func start() {}
    public func stop() {}

    public func refreshSnapshot() async -> Result<PlaybackSnapshot, PlaybackError> {
        .success(currentSnapshot ?? .idle(capabilities: .spotify))
    }

    public func perform(_ command: PlaybackCommand) async -> Result<Void, PlaybackError> {
        guard var snapshot = currentSnapshot else { return .failure(.playerNotRunning) }
        switch command {
        case .play:
            snapshot = Self.resnapshot(snapshot, state: .playing)
        case .pause:
            snapshot = Self.resnapshot(snapshot, state: .paused)
        case .playPause:
            snapshot = Self.resnapshot(snapshot, state: snapshot.state == .playing ? .paused : .playing)
        case .next, .previous:
            break // scenario-driven; use `advance(to:)` in tests/demo instead
        case .seek(let seconds):
            snapshot = PlaybackSnapshot(
                track: snapshot.track, state: snapshot.state, reportedPosition: seconds,
                capturedAt: .now, volume: snapshot.volume, shuffle: snapshot.shuffle,
                repeatMode: snapshot.repeatMode, capabilities: snapshot.capabilities
            )
        case .setVolume(let value):
            snapshot = PlaybackSnapshot(
                track: snapshot.track, state: snapshot.state, reportedPosition: snapshot.reportedPosition,
                capturedAt: snapshot.capturedAt, volume: value, shuffle: snapshot.shuffle,
                repeatMode: snapshot.repeatMode, capabilities: snapshot.capabilities
            )
        case .setShuffle(let value):
            snapshot = PlaybackSnapshot(
                track: snapshot.track, state: snapshot.state, reportedPosition: snapshot.reportedPosition,
                capturedAt: snapshot.capturedAt, volume: snapshot.volume, shuffle: value,
                repeatMode: snapshot.repeatMode, capabilities: snapshot.capabilities
            )
        case .setRepeatMode(let mode):
            snapshot = PlaybackSnapshot(
                track: snapshot.track, state: snapshot.state, reportedPosition: snapshot.reportedPosition,
                capturedAt: snapshot.capturedAt, volume: snapshot.volume, shuffle: snapshot.shuffle,
                repeatMode: mode, capabilities: snapshot.capabilities
            )
        }
        publish(snapshot)
        return .success(())
    }

    // MARK: - Scenario driving (test / demo only)

    private var currentSnapshot: PlaybackSnapshot?

    /// Publishes a brand-new snapshot as if the provider's underlying app just reported it.
    public func publish(_ snapshot: PlaybackSnapshot) {
        currentSnapshot = snapshot
        continuation.yield(.snapshotUpdated(snapshot))
    }

    public func simulateApplicationLaunch() {
        isRunning = true
        continuation.yield(.applicationLaunched)
    }

    public func simulateApplicationTermination() {
        isRunning = false
        currentSnapshot = nil
        continuation.yield(.applicationTerminated)
    }

    private static func resnapshot(_ snapshot: PlaybackSnapshot, state: PlaybackState) -> PlaybackSnapshot {
        PlaybackSnapshot(
            track: snapshot.track, state: state, reportedPosition: snapshot.reportedPosition,
            capturedAt: .now, volume: snapshot.volume, shuffle: snapshot.shuffle,
            repeatMode: snapshot.repeatMode, capabilities: snapshot.capabilities
        )
    }
}

extension MockPlaybackProvider {
    /// Canned scenarios for the Developer menu and for unit/UI smoke tests.
    public enum Scenario {
        case normalTrack
        case veryLongTitles
        case missingArtwork
        case rapidSkips
        case variedColors
    }

    public static func track(
        title: String, artist: String, album: String, durationSeconds: TimeInterval = 200,
        artwork: ArtworkSource = .none, id: String = UUID().uuidString
    ) -> Track {
        Track(
            id: id, provider: .spotify, title: title, artist: artist, album: album,
            albumArtist: artist, duration: .seconds(durationSeconds), artwork: artwork,
            externalURL: URL(string: "https://open.spotify.com/track/\(id)")
        )
    }

    public static func snapshot(for track: Track, state: PlaybackState = .playing, position: TimeInterval = 0) -> PlaybackSnapshot {
        PlaybackSnapshot(
            track: track, state: state, reportedPosition: position, capturedAt: .now,
            volume: 70, shuffle: false, repeatMode: .off, capabilities: .spotify
        )
    }
}
