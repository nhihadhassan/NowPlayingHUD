import AppKit

/// The application delegate. Deliberately thin: it owns one `AppEnvironment` and forwards
/// lifecycle events to it. `NSApplication.activationPolicy` is set to `.accessory` here (in
/// addition to `LSUIElement` in Info.plist, belt-and-suspenders) so the app never shows a Dock
/// icon or appears in Cmd-Tab, matching "the application should primarily live in the menu bar."
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let environment = AppEnvironment()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        environment.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        environment.stop()
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
