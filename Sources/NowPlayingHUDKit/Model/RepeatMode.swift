import Foundation

/// A unified repeat mode across players.
///
/// Spotify's scripting interface only exposes a boolean `repeating` (off/on-for-queue).
/// Apple Music's `song repeat` is a genuine tri-state (off/one/all). Rather than lying about
/// Spotify supporting "repeat one", `SpotifyPlaybackProvider` never reports `.one` and the UI
/// hides that option when `PlayerCapabilities` lacks `.repeatOne`.
public enum RepeatMode: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case off
    case all
    case one

    /// Cycles to the next mode a given player supports, skipping unsupported ones.
    public func next(supporting capabilities: PlayerCapabilities) -> RepeatMode {
        var candidate = self
        for _ in 0..<3 {
            candidate = candidate.rawNext
            switch candidate {
            case .off:
                return .off
            case .all:
                if capabilities.contains(.repeatAll) { return .all }
            case .one:
                if capabilities.contains(.repeatOne) { return .one }
            }
        }
        return .off
    }

    private var rawNext: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    public var symbolName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    public var isActive: Bool { self != .off }
}
