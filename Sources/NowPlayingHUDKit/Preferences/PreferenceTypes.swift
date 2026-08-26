import Foundation

/// Where the HUD appears on screen. `smartTopCenter` is the default: it behaves like
/// `topCenter` on any display without a camera housing, and tucks itself below/around the notch
/// on displays that have one (see `ScreenPositioningService`).
public enum HUDPosition: String, Codable, CaseIterable, Sendable, Identifiable {
    case smartTopCenter
    case topCenter
    case topLeft
    case topRight
    case bottomCenter
    case bottomLeft
    case bottomRight

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .smartTopCenter: return "Smart Top Center"
        case .topCenter: return "Top Center"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomCenter: return "Bottom Center"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

/// Which display receives the HUD.
public enum MonitorBehavior: String, Codable, CaseIterable, Sendable, Identifiable {
    /// The display currently under the mouse pointer — the default, since it's the display the
    /// user is most likely looking at right now.
    case displayWithMouse
    case mainDisplay
    /// A specific display, identified separately by `PreferencesStore.selectedDisplayID`.
    case selectedDisplay
    case allDisplays

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .displayWithMouse: return "Display with Mouse Pointer"
        case .mainDisplay: return "Main Display"
        case .selectedDisplay: return "Selected Display"
        case .allDisplays: return "All Displays"
        }
    }
}

public enum HUDVisualStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case glass
    case compact
    case minimal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .glass: return "Glass"
        case .compact: return "Compact"
        case .minimal: return "Minimal"
        }
    }
}

public enum HUDSize: String, Codable, CaseIterable, Sendable, Identifiable {
    case small
    case medium
    case large

    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }

    /// The compact (non-hovered) width in points, before Retina/backing-scale considerations.
    public var compactWidth: CGFloat {
        switch self {
        case .small: return 260
        case .medium: return 320
        case .large: return 400
        }
    }

    public var artworkSize: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 56
        }
    }
}

public enum AppearanceMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case automatic
    case light
    case dark

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// How much the HUD animates. `system` (default) defers entirely to the user's Reduce Motion
/// accessibility setting; `reduced` requests calmer animations even when the system setting is
/// off, for users who find the default a little too lively without wanting to change a
/// system-wide accessibility setting just for this one app.
public enum AnimationPreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case system
    case full
    case reduced

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .system: return "Match System"
        case .full: return "Full"
        case .reduced: return "Reduced"
        }
    }
}

/// What clicking the artwork/track info in the HUD does.
public enum HUDClickAction: String, Codable, CaseIterable, Sendable, Identifiable {
    case openInPlayer
    case expandPlayer
    case none

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .openInPlayer: return "Open in Player"
        case .expandPlayer: return "Expand Player"
        case .none: return "Do Nothing"
        }
    }
}

/// What the `NSStatusItem` shows.
public enum MenuBarDisplayMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case iconOnly
    case animatedIndicator
    case trackTitle
    case artistDashTrack
    case compactTwoLine

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .iconOnly: return "Icon Only"
        case .animatedIndicator: return "Animated Playback Indicator"
        case .trackTitle: return "Track Title"
        case .artistDashTrack: return "Artist — Track"
        case .compactTwoLine: return "Compact Two-Line"
        }
    }
}
