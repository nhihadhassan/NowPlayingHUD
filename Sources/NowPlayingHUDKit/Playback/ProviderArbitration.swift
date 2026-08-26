import Foundation

/// The player a user wants driving the HUD/menu bar, as a preference.
public enum PlayerSelectionMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case spotify
    case appleMusic

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }
}

/// Per-provider bookkeeping `chooseActiveProvider` needs to make a deterministic call: the most
/// recent snapshot it reported, and when it last said anything at all.
public struct ProviderStanding: Sendable {
    public let identifier: PlayerIdentifier
    public let snapshot: PlaybackSnapshot?
    public let lastEventAt: ContinuousClock.Instant?

    public init(identifier: PlayerIdentifier, snapshot: PlaybackSnapshot?, lastEventAt: ContinuousClock.Instant?) {
        self.identifier = identifier
        self.snapshot = snapshot
        self.lastEventAt = lastEventAt
    }
}

/// Pure decision function for "Automatic" player selection — kept free of any provider/AppKit
/// dependency so it's directly unit-testable.
///
/// Rule (deterministic, per spec): prefer whichever provider is currently `.playing`; if both
/// are playing, prefer whichever most recently emitted an event; if neither is playing, prefer
/// the previously-active provider (so a pause doesn't cause a flicker to the other player), and
/// only fall back to Spotify if there is no previous choice or it's no longer a candidate.
public enum ProviderArbitration {
    public static func chooseActiveProvider(
        previousChoice: PlayerIdentifier?,
        candidates: [ProviderStanding]
    ) -> PlayerIdentifier? {
        let running = candidates.filter { $0.snapshot != nil }
        guard !running.isEmpty else { return nil }

        let playing = running.filter { $0.snapshot?.state == .playing }
        if playing.count == 1 {
            return playing[0].identifier
        }
        if playing.count > 1 {
            // Both playing: most recently active wins.
            return playing.max { (lhs, rhs) in
                (lhs.lastEventAt ?? .now) < (rhs.lastEventAt ?? .now)
            }?.identifier
        }

        // Nobody is playing: stick with the previous choice if it's still a candidate.
        if let previousChoice, running.contains(where: { $0.identifier == previousChoice }) {
            return previousChoice
        }
        // Otherwise prefer Spotify, then whatever's left.
        if let spotify = running.first(where: { $0.identifier == .spotify }) {
            return spotify.identifier
        }
        return running.first?.identifier
    }
}
