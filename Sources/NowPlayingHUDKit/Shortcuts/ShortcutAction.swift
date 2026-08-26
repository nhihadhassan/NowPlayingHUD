import Foundation

/// A user-triggerable global action. Nothing is bound to any of these by default — the user
/// opts in per-action in Settings → Shortcuts, so this app never silently hijacks a combination
/// they already use elsewhere.
public enum ShortcutAction: String, Codable, CaseIterable, Sendable, Identifiable {
    case toggleHUD
    case playPause
    case next
    case previous
    case volumeUp
    case volumeDown
    case seekForward
    case seekBackward

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .toggleHUD: return "Show/Hide Now Playing HUD"
        case .playPause: return "Play/Pause"
        case .next: return "Next Track"
        case .previous: return "Previous Track"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .seekForward: return "Seek Forward"
        case .seekBackward: return "Seek Backward"
        }
    }

    public var symbolName: String {
        switch self {
        case .toggleHUD: return "rectangle.on.rectangle"
        case .playPause: return "playpause.fill"
        case .next: return "forward.end.fill"
        case .previous: return "backward.end.fill"
        case .volumeUp: return "speaker.wave.3.fill"
        case .volumeDown: return "speaker.wave.1.fill"
        case .seekForward: return "goforward.15"
        case .seekBackward: return "gobackward.15"
        }
    }
}
