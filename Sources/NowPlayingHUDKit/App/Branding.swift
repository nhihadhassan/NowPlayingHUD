import Foundation

/// The single source of truth for the app's name and identifiers within Swift code. Renaming the
/// app is a two-step edit: this file, and the `APP_NAME`/`BUNDLE_ID` variables at the top of the
/// `Makefile` (which generate `Info.plist` from `Resources/Info.plist.in`).
public enum Branding {
    public static let appName = "NowPlayingHUD"
    public static let bundleIdentifier = "com.nowplayinghud.app"
    public static let githubURL = URL(string: "https://github.com/")!
}
