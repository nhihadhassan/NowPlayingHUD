import AppKit
import Foundation
import Observation

/// One tick of the coordinator's output: the latest unified snapshot, plus whether it represents
/// a track/state change significant enough to (re)present the HUD and restart its dismissal
/// timer, as opposed to an incidental refinement (e.g. Spotify's phase-2 artwork-URL enrichment)
/// that should update bound UI in place without any of that.
public struct PlaybackCoordinatorEvent: Sendable, Equatable {
    public let snapshot: PlaybackSnapshot
    public let isSignificant: Bool
}

/// Owns every `PlaybackProvider`, decides which one is "active" (per `PlayerSelectionMode`), and
/// publishes one unified, deduplicated stream of playback state — so nothing downstream (the HUD,
/// the menu bar, the mini player) needs to know how many players exist or which one is current.
@MainActor
@Observable
public final class PlaybackCoordinator {
    public private(set) var currentSnapshot: PlaybackSnapshot = .idle()
    public private(set) var activeProvider: PlayerIdentifier?

    public var selectionMode: PlayerSelectionMode = .automatic {
        didSet { reevaluateActiveProvider() }
    }

    public let significantEvents: AsyncStream<PlaybackCoordinatorEvent>
    private let significantContinuation: AsyncStream<PlaybackCoordinatorEvent>.Continuation

    private let providers: [PlayerIdentifier: PlaybackProvider]
    private var standings: [PlayerIdentifier: ProviderStanding] = [:]
    private var listenTasks: [Task<Void, Never>] = []

    public init(providers: [PlaybackProvider]) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.identifier, $0) })
        var continuation: AsyncStream<PlaybackCoordinatorEvent>.Continuation!
        significantEvents = AsyncStream { continuation = $0 }
        significantContinuation = continuation
    }

    /// Whether a given player is installed on this Mac at all (Settings uses this to decide
    /// whether to offer it as a `player` choice).
    public func isInstalled(_ identifier: PlayerIdentifier) -> Bool {
        providers[identifier]?.isInstalled ?? false
    }

    public func isRunning(_ identifier: PlayerIdentifier) -> Bool {
        providers[identifier]?.isRunning ?? false
    }

    public var anyProviderRunning: Bool {
        providers.values.contains { $0.isRunning }
    }

    public func start() {
        for provider in providers.values {
            provider.start()
            let identifier = provider.identifier
            let stream = provider.events
            let task = Task { @MainActor [weak self] in
                for await event in stream {
                    self?.handle(event, from: identifier)
                }
            }
            listenTasks.append(task)

            // Covers "Spotify already playing when we launch": one immediate fetch per provider,
            // never repeated on a timer.
            Task { @MainActor [weak self] in
                let result = await provider.refreshSnapshot()
                if case .success(let snapshot) = result {
                    self?.handle(.snapshotUpdated(snapshot), from: identifier)
                }
            }
        }
    }

    public func stop() {
        for task in listenTasks { task.cancel() }
        listenTasks.removeAll()
        for provider in providers.values { provider.stop() }
    }

    /// Routes a command to whichever provider is currently active. Returns `.playerNotRunning`
    /// if none is.
    public func perform(_ command: PlaybackCommand) async -> Result<Void, PlaybackError> {
        guard let activeProvider, let provider = providers[activeProvider] else {
            return .failure(.playerNotRunning)
        }
        return await provider.perform(command)
    }

    /// Fetches raw Apple Music artwork bytes for `trackID`, if the active/relevant provider
    /// supports it. Returns `nil` for Spotify tracks (which use `ArtworkSource.remote` instead).
    public func fetchAppleMusicArtwork(trackID: String) async -> Data? {
        guard let music = providers[.appleMusic] as? AppleMusicPlaybackProvider else { return nil }
        return await music.fetchArtworkData(trackID: trackID)
    }

    /// Opens (or brings to the foreground) the given player, for the menu bar's
    /// "Launch Spotify" / empty-state action.
    public func launchApp(for identifier: PlayerIdentifier) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier.bundleIdentifier) else { return }
        NSWorkspace.shared.open(url)
    }

    private func handle(_ event: ProviderEvent, from identifier: PlayerIdentifier) {
        switch event {
        case .applicationLaunched:
            let existing = standings[identifier]
            standings[identifier] = ProviderStanding(identifier: identifier, snapshot: existing?.snapshot, lastEventAt: .now)
        case .applicationTerminated:
            standings[identifier] = ProviderStanding(identifier: identifier, snapshot: nil, lastEventAt: .now)
        case .snapshotUpdated(let snapshot):
            standings[identifier] = ProviderStanding(identifier: identifier, snapshot: snapshot, lastEventAt: .now)
        }
        reevaluateActiveProvider()
    }

    private func reevaluateActiveProvider() {
        let newActive: PlayerIdentifier?
        switch selectionMode {
        case .spotify:
            newActive = standings[.spotify]?.snapshot != nil ? .spotify : nil
        case .appleMusic:
            newActive = standings[.appleMusic]?.snapshot != nil ? .appleMusic : nil
        case .automatic:
            newActive = ProviderArbitration.chooseActiveProvider(
                previousChoice: activeProvider,
                candidates: Array(standings.values)
            )
        }
        activeProvider = newActive
        let newSnapshot = newActive.flatMap { standings[$0]?.snapshot } ?? .idle()
        publish(newSnapshot)
    }

    private func publish(_ snapshot: PlaybackSnapshot) {
        let significant = snapshot.isSignificantChange(from: currentSnapshot)
        currentSnapshot = snapshot
        significantContinuation.yield(PlaybackCoordinatorEvent(snapshot: snapshot, isSignificant: significant))
    }
}

