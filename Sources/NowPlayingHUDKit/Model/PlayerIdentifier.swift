import Foundation

/// Identifies which local media player a piece of state or a command refers to.
/// New providers are added here and in `PlaybackCoordinator` — nowhere else needs to change.
public enum PlayerIdentifier: String, Codable, CaseIterable, Sendable, Identifiable, Equatable, Hashable {
    case spotify
    case appleMusic

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }

    /// The bundle identifier of the underlying application.
    public var bundleIdentifier: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .appleMusic: return "com.apple.Music"
        }
    }

    /// The `com.apple.symbolic.hierarchical`-friendly SF Symbol used to represent this player.
    public var symbolName: String {
        switch self {
        case .spotify: return "music.note.list"
        case .appleMusic: return "music.note"
        }
    }
}
