import Foundation

/// What a given player's scripting interface actually supports.
///
/// Spotify and Apple Music expose meaningfully different control surfaces (see README
/// "Known limitations"). Rather than sprinkling `if provider == .spotify` checks through the UI,
/// each provider reports its `PlayerCapabilities` once, and the UI enables/disables/hides controls
/// from that single source of truth.
public struct PlayerCapabilities: OptionSet, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Writing `player position` (Spotify) or an equivalent seek command (Apple Music).
    public static let seek = PlayerCapabilities(rawValue: 1 << 0)
    /// Reading/writing the player's output volume.
    public static let volume = PlayerCapabilities(rawValue: 1 << 1)
    /// Toggling shuffle on/off.
    public static let shuffle = PlayerCapabilities(rawValue: 1 << 2)
    /// A repeat mode that cycles the whole queue ("repeat all").
    public static let repeatAll = PlayerCapabilities(rawValue: 1 << 3)
    /// A distinct "repeat one" mode. Spotify's scripting interface has no such mode
    /// (`repeating` is a plain boolean) — only Apple Music reports this.
    public static let repeatOne = PlayerCapabilities(rawValue: 1 << 4)
    /// Artwork is available as a directly fetchable URL (Spotify). Apple Music instead exposes
    /// raw image bytes over Apple Events, which is handled separately by `ArtworkSource`.
    public static let artworkURL = PlayerCapabilities(rawValue: 1 << 5)
    /// Reading enabled/disabled flags for shuffle/repeat independent of their current value.
    /// Spotify's own scripting dictionary assigns "shuffling enabled" and "repeating enabled"
    /// the same four-char code (`pReE`), making the pair ambiguous to address reliably, so
    /// Spotify never reports this bit — see `SpotifyPlaybackProvider`.
    public static let enabledFlags = PlayerCapabilities(rawValue: 1 << 6)

    public static let spotify: PlayerCapabilities = [.seek, .volume, .shuffle, .repeatAll, .artworkURL]
    public static let appleMusic: PlayerCapabilities = [.seek, .volume, .shuffle, .repeatAll, .repeatOne, .enabledFlags]
}
