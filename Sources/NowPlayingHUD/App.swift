import AppKit
import NowPlayingHUDKit

@main
struct NowPlayingHUDMain {
    @MainActor
    static func main() {
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
