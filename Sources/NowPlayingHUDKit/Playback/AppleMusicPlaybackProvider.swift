import Foundation
import AppKit
import os

/// The Apple Music provider, driven by `com.apple.Music.playerInfo`.
///
/// Unlike `SpotifyPlaybackProvider`, this provider treats every notification purely as a
/// **trigger** and always re-derives state from a fresh, sdef-verified Apple Event snapshot —
/// see `MusicScript.notificationIsTriggerOnly` for why no notification-payload fast path is used
/// here. It is still fully event-driven; there is no polling timer.
public final class AppleMusicPlaybackProvider: PlaybackProvider, @unchecked Sendable {
    public let identifier: PlayerIdentifier = .appleMusic
    public let events: AsyncStream<ProviderEvent>

    private let bridge = AppleEventBridge(label: "com.nowplayinghud.music.ae")
    private let eventContinuation: AsyncStream<ProviderEvent>.Continuation
    private let box = OSAllocatedUnfairLock<Box>(initialState: Box())

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

    public func start() {
        guard distributedObserver == nil else { return }

        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshAndPublish() }
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

    private func refreshAndPublish() async {
        guard case .success(let snapshot) = await refreshSnapshot() else { return }
        box.withLock { $0.lastSnapshot = snapshot }
        eventContinuation.yield(.snapshotUpdated(snapshot))
    }

    public func refreshSnapshot() async -> Result<PlaybackSnapshot, PlaybackError> {
        guard isRunning else { return .success(.idle()) }
        do {
            let descriptor = try await bridge.run(MusicScript.snapshot)
            return .success(MusicScript.parseSnapshot(descriptor))
        } catch {
            return .failure(Self.mapError(error))
        }
    }

    public func perform(_ command: PlaybackCommand) async -> Result<Void, PlaybackError> {
        guard isRunning else { return .failure(.playerNotRunning) }
        let script: String
        switch command {
        case .play: script = MusicScript.play
        case .pause: script = MusicScript.pause
        case .playPause: script = MusicScript.playPause
        case .next: script = MusicScript.next
        case .previous: script = MusicScript.previous
        case .seek(let seconds): script = MusicScript.seek(to: seconds)
        case .setVolume(let value): script = MusicScript.setVolume(value)
        case .setShuffle(let value): script = MusicScript.setShuffle(value)
        case .setRepeatMode(let mode): script = MusicScript.setRepeat(mode)
        }
        do {
            try await bridge.run(script)
            return .success(())
        } catch {
            return .failure(Self.mapError(error))
        }
    }

    /// Fetches raw artwork image data for `trackID`, or `nil` if unavailable, the track has
    /// already changed, or Automation isn't permitted. Called lazily by `ArtworkService` only
    /// when a Music track's artwork is actually about to be displayed.
    public func fetchArtworkData(trackID: String) async -> Data? {
        guard isRunning else { return nil }
        guard let descriptor = try? await bridge.run(MusicScript.fetchArtwork(trackID: trackID)) else {
            return nil
        }
        let data = descriptor.data
        return data.isEmpty ? nil : data
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
}
