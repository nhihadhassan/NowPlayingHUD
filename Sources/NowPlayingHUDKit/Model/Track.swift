import Foundation

/// Where a track's artwork can be obtained from.
public enum ArtworkSource: Sendable, Equatable {
    /// A directly fetchable URL — Spotify's `artwork url` property.
    case remote(URL)
    /// Apple Music exposes artwork as raw image bytes over Apple Events rather than a URL;
    /// this case carries a stable cache key (the track's persistent ID) so `ArtworkService`
    /// can dedupe/cache it the same way as a remote URL, while the actual bytes are fetched
    /// lazily via `AppleMusicPlaybackProvider.fetchArtworkData(for:)`.
    case appleEventBytes(cacheKey: String)
    /// No artwork is available for this track.
    case none
}

/// A player-agnostic snapshot of "what track is this". Immutable value type — safe to pass
/// across actors and compare for equality without touching AppKit.
public struct Track: Sendable, Equatable, Identifiable {
    /// A stable identifier for the track, unique within its provider
    /// (Spotify URI e.g. "spotify:track:...", or Apple Music's persistent/database ID).
    /// Used as the cache key for artwork and as the basis for change/duplicate detection.
    public let id: String
    public let provider: PlayerIdentifier
    public let title: String
    public let artist: String
    public let album: String
    public let albumArtist: String?
    /// Track duration. Spotify reports this in **milliseconds** despite its sdef claiming
    /// seconds (verified empirically); Apple Music reports real seconds. Both providers
    /// normalize to `Duration` before constructing a `Track`, so nothing downstream needs to
    /// know about the discrepancy.
    public let duration: Duration
    public let artwork: ArtworkSource
    /// A user-facing URL to open the track in its owning application (Spotify web/URI link,
    /// or a Music.app deep link).
    public let externalURL: URL?

    public init(
        id: String,
        provider: PlayerIdentifier,
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        duration: Duration,
        artwork: ArtworkSource = .none,
        externalURL: URL? = nil
    ) {
        self.id = id
        self.provider = provider
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.duration = duration
        self.artwork = artwork
        self.externalURL = externalURL
    }

    /// "Track — Artist", used by the "Copy Track — Artist" context action.
    public var copyableSummary: String { "\(title) — \(artist)" }
}
