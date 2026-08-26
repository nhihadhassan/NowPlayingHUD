import Foundation

public enum PlaybackState: String, Codable, Sendable, Equatable, Hashable {
    case stopped
    case paused
    case playing
}
