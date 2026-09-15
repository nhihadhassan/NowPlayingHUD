import Foundation
import Observation

/// All persisted user preferences, backed by `UserDefaults`/`@AppStorage`-style persistence but
/// exposed as a single `@Observable` object so SwiftUI views (Settings, the live preview, the
/// menu bar popover) simply bind to properties rather than talking to `UserDefaults` directly.
///
/// `defaults` is injectable so tests can exercise persistence against an isolated suite instead
/// of polluting the real one.
@Observable
public final class PreferencesStore {
    @ObservationIgnored private let defaults: UserDefaults

    // MARK: - General

    public var automaticHUDEnabled: Bool {
        didSet { defaults.set(automaticHUDEnabled, forKey: PreferenceKeys.automaticHUDEnabled) }
    }
    public var playerSelectionMode: PlayerSelectionMode {
        didSet { defaults.set(playerSelectionMode.rawValue, forKey: PreferenceKeys.playerSelectionMode) }
    }
    public var showMenuBarItem: Bool {
        didSet { defaults.set(showMenuBarItem, forKey: PreferenceKeys.showMenuBarItem) }
    }
    public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { defaults.set(menuBarDisplayMode.rawValue, forKey: PreferenceKeys.menuBarDisplayMode) }
    }
    public var showOverFullScreenApps: Bool {
        didSet { defaults.set(showOverFullScreenApps, forKey: PreferenceKeys.showOverFullScreenApps) }
    }
    /// Default true: seeing the HUD pop up while you're looking straight at Spotify, actively
    /// clicking tracks yourself, is the annoying case this avoids.
    public var hideWhenPlayerFrontmost: Bool {
        didSet { defaults.set(hideWhenPlayerFrontmost, forKey: PreferenceKeys.hideWhenPlayerFrontmost) }
    }

    // MARK: - HUD

    public var hudPosition: HUDPosition {
        didSet { defaults.set(hudPosition.rawValue, forKey: PreferenceKeys.hudPosition) }
    }
    public var monitorBehavior: MonitorBehavior {
        didSet { defaults.set(monitorBehavior.rawValue, forKey: PreferenceKeys.monitorBehavior) }
    }
    public var selectedDisplayID: String? {
        didSet { defaults.set(selectedDisplayID, forKey: PreferenceKeys.selectedDisplayID) }
    }
    public var displayDurationSeconds: Double {
        didSet { defaults.set(displayDurationSeconds, forKey: PreferenceKeys.displayDurationSeconds) }
    }
    public var edgeOffset: Double {
        didSet { defaults.set(edgeOffset, forKey: PreferenceKeys.edgeOffset) }
    }
    public var hoverToExpand: Bool {
        didSet { defaults.set(hoverToExpand, forKey: PreferenceKeys.hoverToExpand) }
    }
    public var hoverDismissDelaySeconds: Double {
        didSet { defaults.set(hoverDismissDelaySeconds, forKey: PreferenceKeys.hoverDismissDelaySeconds) }
    }
    public var showOnTrackChange: Bool {
        didSet { defaults.set(showOnTrackChange, forKey: PreferenceKeys.showOnTrackChange) }
    }
    public var showOnPlayResume: Bool {
        didSet { defaults.set(showOnPlayResume, forKey: PreferenceKeys.showOnPlayResume) }
    }
    public var showOnPause: Bool {
        didSet { defaults.set(showOnPause, forKey: PreferenceKeys.showOnPause) }
    }
    /// Even when `showOnPlayResume`/`showOnPause` are off, an action the user took *through this
    /// app itself* (menu bar popover, HUD controls, or a global shortcut) still shows the HUD as
    /// confirmation of what just happened.
    public var showOnManualControl: Bool {
        didSet { defaults.set(showOnManualControl, forKey: PreferenceKeys.showOnManualControl) }
    }

    // MARK: - Content

    public var showAlbumArt: Bool { didSet { defaults.set(showAlbumArt, forKey: PreferenceKeys.showAlbumArt) } }
    public var showTitle: Bool { didSet { defaults.set(showTitle, forKey: PreferenceKeys.showTitle) } }
    public var showArtist: Bool { didSet { defaults.set(showArtist, forKey: PreferenceKeys.showArtist) } }
    public var showAlbum: Bool { didSet { defaults.set(showAlbum, forKey: PreferenceKeys.showAlbum) } }
    public var showProgress: Bool { didSet { defaults.set(showProgress, forKey: PreferenceKeys.showProgress) } }
    public var showTime: Bool { didSet { defaults.set(showTime, forKey: PreferenceKeys.showTime) } }
    public var showControls: Bool { didSet { defaults.set(showControls, forKey: PreferenceKeys.showControls) } }

    // MARK: - Appearance

    public var hudStyle: HUDVisualStyle { didSet { defaults.set(hudStyle.rawValue, forKey: PreferenceKeys.hudStyle) } }
    public var hudSize: HUDSize { didSet { defaults.set(hudSize.rawValue, forKey: PreferenceKeys.hudSize) } }
    public var appearanceMode: AppearanceMode { didSet { defaults.set(appearanceMode.rawValue, forKey: PreferenceKeys.appearanceMode) } }
    public var accentFromArtwork: Bool { didSet { defaults.set(accentFromArtwork, forKey: PreferenceKeys.accentFromArtwork) } }
    public var animationPreference: AnimationPreference { didSet { defaults.set(animationPreference.rawValue, forKey: PreferenceKeys.animationPreference) } }

    // MARK: - Controls

    public var primaryClickAction: HUDClickAction { didSet { defaults.set(primaryClickAction.rawValue, forKey: PreferenceKeys.primaryClickAction) } }

    // MARK: - Shortcuts

    public var shortcutBindings: [ShortcutAction: KeyCombo] {
        didSet {
            let encoded = shortcutBindings.reduce(into: [String: KeyCombo]()) { $0[$1.key.rawValue] = $1.value }
            if let data = try? JSONEncoder().encode(encoded) {
                defaults.set(data, forKey: PreferenceKeys.shortcutBindings)
            }
        }
    }

    // MARK: - Advanced

    /// Not exposed as a Settings toggle at all — enabled only via
    /// `defaults write <bundle-id> NPHDeveloperMode -bool true` in Terminal, per the "nothing
    /// ugly in the production UI" requirement. Advanced pane reads this to reveal a Developer
    /// section only when it's already true.
    public var developerModeEnabled: Bool {
        defaults.bool(forKey: PreferenceKeys.developerModeEnabled)
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        automaticHUDEnabled = defaults.object(forKey: PreferenceKeys.automaticHUDEnabled) as? Bool ?? true
        playerSelectionMode = (defaults.string(forKey: PreferenceKeys.playerSelectionMode)).flatMap(PlayerSelectionMode.init) ?? .automatic
        showMenuBarItem = defaults.object(forKey: PreferenceKeys.showMenuBarItem) as? Bool ?? true
        menuBarDisplayMode = (defaults.string(forKey: PreferenceKeys.menuBarDisplayMode)).flatMap(MenuBarDisplayMode.init) ?? .iconOnly
        showOverFullScreenApps = defaults.object(forKey: PreferenceKeys.showOverFullScreenApps) as? Bool ?? true
        hideWhenPlayerFrontmost = defaults.object(forKey: PreferenceKeys.hideWhenPlayerFrontmost) as? Bool ?? true

        hudPosition = (defaults.string(forKey: PreferenceKeys.hudPosition)).flatMap(HUDPosition.init) ?? .smartTopCenter
        monitorBehavior = (defaults.string(forKey: PreferenceKeys.monitorBehavior)).flatMap(MonitorBehavior.init) ?? .displayWithMouse
        selectedDisplayID = defaults.string(forKey: PreferenceKeys.selectedDisplayID)
        displayDurationSeconds = defaults.object(forKey: PreferenceKeys.displayDurationSeconds) as? Double ?? 3.0
        edgeOffset = defaults.object(forKey: PreferenceKeys.edgeOffset) as? Double ?? 12.0
        hoverToExpand = defaults.object(forKey: PreferenceKeys.hoverToExpand) as? Bool ?? true
        hoverDismissDelaySeconds = defaults.object(forKey: PreferenceKeys.hoverDismissDelaySeconds) as? Double ?? 1.5
        showOnTrackChange = defaults.object(forKey: PreferenceKeys.showOnTrackChange) as? Bool ?? true
        showOnPlayResume = defaults.object(forKey: PreferenceKeys.showOnPlayResume) as? Bool ?? true
        showOnPause = defaults.object(forKey: PreferenceKeys.showOnPause) as? Bool ?? false
        showOnManualControl = defaults.object(forKey: PreferenceKeys.showOnManualControl) as? Bool ?? true

        showAlbumArt = defaults.object(forKey: PreferenceKeys.showAlbumArt) as? Bool ?? true
        showTitle = defaults.object(forKey: PreferenceKeys.showTitle) as? Bool ?? true
        showArtist = defaults.object(forKey: PreferenceKeys.showArtist) as? Bool ?? true
        showAlbum = defaults.object(forKey: PreferenceKeys.showAlbum) as? Bool ?? true
        showProgress = defaults.object(forKey: PreferenceKeys.showProgress) as? Bool ?? true
        showTime = defaults.object(forKey: PreferenceKeys.showTime) as? Bool ?? true
        showControls = defaults.object(forKey: PreferenceKeys.showControls) as? Bool ?? true

        hudStyle = (defaults.string(forKey: PreferenceKeys.hudStyle)).flatMap(HUDVisualStyle.init) ?? .glass
        hudSize = (defaults.string(forKey: PreferenceKeys.hudSize)).flatMap(HUDSize.init) ?? .medium
        appearanceMode = (defaults.string(forKey: PreferenceKeys.appearanceMode)).flatMap(AppearanceMode.init) ?? .automatic
        accentFromArtwork = defaults.object(forKey: PreferenceKeys.accentFromArtwork) as? Bool ?? true
        animationPreference = (defaults.string(forKey: PreferenceKeys.animationPreference)).flatMap(AnimationPreference.init) ?? .system

        primaryClickAction = (defaults.string(forKey: PreferenceKeys.primaryClickAction)).flatMap(HUDClickAction.init) ?? .openInPlayer

        if let data = defaults.data(forKey: PreferenceKeys.shortcutBindings),
           let decoded = try? JSONDecoder().decode([String: KeyCombo].self, from: data) {
            shortcutBindings = decoded.reduce(into: [ShortcutAction: KeyCombo]()) { result, pair in
                if let action = ShortcutAction(rawValue: pair.key) { result[action] = pair.value }
            }
        } else {
            shortcutBindings = [:] // Nothing bound by default — the user opts in.
        }
    }
}
