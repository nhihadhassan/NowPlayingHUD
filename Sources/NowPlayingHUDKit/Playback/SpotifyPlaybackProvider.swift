import Foundation
import AppKit
import os

/// The primary, event-driven playback source: Spotify's own
/// `com.spotify.client.PlaybackStateChanged` distributed notification, treated purely as a
/// trigger — never polled.
///
/// Every notification drives a **two-phase update**:
/// 1. Immediately publish a snapshot built straight from the notification's `userInfo` (title,
///    artist, album, duration, position, play state — all verified present on a live Spotify
///    client). This works even when Automation permission has been denied, so the HUD still
///    shows *something* correct rather than nothing.
/// 2. Kick off a single batched Apple Event round trip (`SpotifyScript.snapshot`) to enrich that
///    with what the notification doesn't carry: artwork URL, volume, shuffle, repeat. If
///    Automation is denied this simply fails silently and phase 1's data stands.
public final class SpotifyPlaybackProvider: PlaybackProvider, @unchecked Sendable {
    public let identifier: PlayerIdentifier = .spotify
    public let events: AsyncStream<ProviderEvent>

    private let bridge = AppleEventBridge(label: "com.nowplayinghud.spotify.ae")
    private let eventContinuation: AsyncStream<ProviderEvent>.Continuation
    private let box = OSAllocatedUnfairLock<Box>(initialState: Box())

    /// Only field that's touched off the main thread (from Apple Event completion handlers on
    /// arbitrary executors), so it alone is lock-protected rather than the whole object.
    private struct Box {
        var lastSnapshot: PlaybackSnapshot?
    }

    private var distributedObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    public init() {
        var continuation: AsyncStream<ProviderEvent>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventContinuation = continuation
    }

    public var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier.bundleIdentifier) != nil
    }

    public var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == identifier.bundleIdentifier }
    }

    /// Must be called on the main actor (`PlaybackCoordinator` owns the call site). Idempotent.
    public func start() {
        guard distributedObserver == nil else { return }

        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleNotification(note)
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        launchObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, self.matches(note) else { return }
            self.eventContinuation.yield(.applicationLaunched)
            Task { await self.refreshAndPublish() }
        }
        terminateObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, self.matches(note) else { return }
            self.box.withLock { $0.lastSnapshot = nil }
            self.eventContinuation.yield(.applicationTerminated)
        }
    }

    public func stop() {
        if let distributedObserver { DistributedNotificationCenter.default().removeObserver(distributedObserver) }
        if let launchObserver { NSWorkspace.shared.notificationCenter.removeObserver(launchObserver) }
        if let terminateObserver { NSWorkspace.shared.notificationCenter.removeObserver(terminateObserver) }
        distributedObserver = nil
        launchObserver = nil
        terminateObserver = nil
    }

    private func matches(_ note: Notification) -> Bool {
        (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
            .bundleIdentifier == identifier.bundleIdentifier
    }

    private func handleNotification(_ note: Notification) {
        if let fast = Self.fastSnapshot(from: note) {
            box.withLock { $0.lastSnapshot = fast }
            eventContinuation.yield(.snapshotUpdated(fast))
        }
        Task { await refreshAndPublish() }
    }

    private func refreshAndPublish() async {
        guard case .success(let snapshot) = await refreshSnapshot() else { return }
        box.withLock { $0.lastSnapshot = snapshot }
        eventContinuation.yield(.snapshotUpdated(snapshot))
    }

    public func refreshSnapshot() async -> Result<PlaybackSnapshot, PlaybackError> {
        guard isRunning else { return .success(.idle()) }
        do {
            let descriptor = try await bridge.run(SpotifyScript.snapshot)
            return .success(SpotifyScript.parseSnapshot(descriptor))
        } catch {
            return .failure(Self.mapError(error))
        }
    }

    public func perform(_ command: PlaybackCommand) async -> Result<Void, PlaybackError> {
        guard isRunning else { return .failure(.playerNotRunning) }

        if case .previous = command {
            return await performSmartPrevious()
        }
        guard let script = Self.script(for: command) else {
            return .failure(.unsupported)
        }
        do {
            try await bridge.run(script)
            return .success(())
        } catch {
            return .failure(Self.mapError(error))
        }
    }

    /// `.previous` is intentionally excluded (returns `nil`) — it's handled separately by
    /// `performSmartPrevious()`, which needs the cached position `perform(_:)` doesn't have.
    private static func script(for command: PlaybackCommand) -> String? {
        switch command {
        case .play: return SpotifyScript.play
        case .pause: return SpotifyScript.pause
        case .playPause: return SpotifyScript.playPause
        case .next: return SpotifyScript.next
        case .previous: return nil
        case .seek(let seconds): return SpotifyScript.seek(to: seconds)
        case .setVolume(let value): return SpotifyScript.setVolume(value)
        case .setShuffle(let value): return SpotifyScript.setShuffle(value)
        case .setRepeatMode(let mode): return SpotifyScript.setRepeat(mode != .off)
        }
    }

    /// Spotify's scripting interface, like most desktop players, only exposes a raw
    /// "previous track" command — the "restart if far enough in" behavior users expect from the
    /// physical/on-screen previous button is implemented here using two direct, non-simulated
    /// scripting primitives (`set player position to 0` / `previous track`), never a keyboard
    /// simulation.
    private func performSmartPrevious() async -> Result<Void, PlaybackError> {
        let restartThreshold: TimeInterval = 3
        let estimatedPosition = box.withLock { box -> TimeInterval in
            guard let snapshot = box.lastSnapshot else { return 0 }
            return ProgressEstimator(snapshot: snapshot).position()
        }
        let script = estimatedPosition > restartThreshold ? SpotifyScript.seek(to: 0) : SpotifyScript.previous
        do {
            try await bridge.run(script)
            return .success(())
        } catch {
            return .failure(Self.mapError(error))
        }
    }

    private static func mapError(_ error: Error) -> PlaybackError {
        guard let scriptError = error as? AppleEventBridge.ScriptError else {
            return .underlying(code: -1, message: "\(error)")
        }
        switch scriptError.code {
        case -600: return .playerNotRunning
        case -1743: return .automationDenied
        case -1712: return .timedOut
        default: return .underlying(code: scriptError.code, message: scriptError.message)
        }
    }

    /// Builds a snapshot straight from `PlaybackStateChanged`'s `userInfo` — verified empirically
    /// to contain `Player State`, `Name`, `Artist`, `Album`, `Album Artist`, `Track ID`,
    /// `Duration` (ms), and `Playback Position` (seconds). No artwork URL is included at this
    /// layer (Spotify's notification doesn't carry one); `capabilities` is left empty so the UI
    /// doesn't show controls it can't yet back with real values until phase 2 arrives.
    static func fastSnapshot(from note: Notification) -> PlaybackSnapshot? {
        guard let info = note.userInfo, let stateString = info["Player State"] as? String else { return nil }

        let state: PlaybackState
        switch stateString {
        case "Playing": state = .playing
        case "Paused": state = .paused
        default: state = .stopped
        }

        var track: Track?
        if let trackID = info["Track ID"] as? String, !trackID.isEmpty {
            let durationMillis = (info["Duration"] as? NSNumber)?.int64Value ?? 0
            track = Track(
                id: trackID,
                provider: .spotify,
                title: (info["Name"] as? String) ?? "",
                artist: (info["Artist"] as? String) ?? "",
                album: (info["Album"] as? String) ?? "",
                albumArtist: info["Album Artist"] as? String,
                duration: .milliseconds(durationMillis),
                artwork: .none,
                externalURL: URL(string: trackID)
            )
        }

        return PlaybackSnapshot(
            track: track,
            state: state,
            reportedPosition: (info["Playback Position"] as? NSNumber)?.doubleValue ?? 0,
            capturedAt: .now,
            volume: 0,
            shuffle: false,
            repeatMode: .off,
            capabilities: []
        )
    }
}
