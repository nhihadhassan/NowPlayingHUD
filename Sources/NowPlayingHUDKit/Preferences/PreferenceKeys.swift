import Foundation

/// Every `UserDefaults` key this app writes, in one place so a full-uninstall instruction
/// (README) and any future migration code have a single source of truth.
enum PreferenceKeys {
    static let automaticHUDEnabled = "automaticHUDEnabled"
    static let playerSelectionMode = "playerSelectionMode"
    static let showMenuBarItem = "showMenuBarItem"
    static let menuBarDisplayMode = "menuBarDisplayMode"
    static let showOverFullScreenApps = "showOverFullScreenApps"
    static let hideWhenPlayerFrontmost = "hideWhenPlayerFrontmost"

    static let hudPosition = "hudPosition"
    static let monitorBehavior = "monitorBehavior"
    static let selectedDisplayID = "selectedDisplayID"
    static let displayDurationSeconds = "displayDurationSeconds"
    static let edgeOffset = "edgeOffset"
    static let hoverToExpand = "hoverToExpand"
    static let hoverDismissDelaySeconds = "hoverDismissDelaySeconds"
    static let showOnTrackChange = "showOnTrackChange"
    static let showOnPlayResume = "showOnPlayResume"
    static let showOnPause = "showOnPause"
    static let showOnManualControl = "showOnManualControl"

    static let showAlbumArt = "showAlbumArt"
    static let showTitle = "showTitle"
    static let showArtist = "showArtist"
    static let showAlbum = "showAlbum"
    static let showProgress = "showProgress"
    static let showTime = "showTime"
    static let showControls = "showControls"

    static let hudStyle = "hudStyle"
    static let hudSize = "hudSize"
    static let appearanceMode = "appearanceMode"
    static let accentFromArtwork = "accentFromArtwork"
    static let animationPreference = "animationPreference"

    static let primaryClickAction = "primaryClickAction"

    static let shortcutBindings = "shortcutBindings"

    static let developerModeEnabled = "NPHDeveloperMode"
}
