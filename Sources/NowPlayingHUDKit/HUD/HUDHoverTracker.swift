import AppKit

/// Detects the pointer entering a screen region **while that window is `ignoresMouseEvents =
/// true`** — i.e. while it isn't receiving any mouse events of its own to observe via a normal
/// `NSTrackingArea`/local monitor.
///
/// This is only necessary for the *entry* half of hover detection on a click-through window.
/// Once `HUDPresentationCoordinator` flips the panel interactive, ordinary SwiftUI `.onHover`/
/// AppKit `mouseExited` handles the exit — this tracker is stopped at that point and restarted
/// only once the panel goes back to being click-through.
///
/// `.mouseMoved` global monitors report raw cursor position without needing Accessibility
/// permission (unlike a `CGEventTap` or a global keyboard monitor) and are only installed while
/// a HUD is actually on screen — typically a few seconds — so this adds no idle-time cost.
final class HUDHoverTracker {
    private var monitor: Any?
    private let onEnter: () -> Void

    init(onEnter: @escaping () -> Void) {
        self.onEnter = onEnter
    }

    /// Starts watching. `frameProvider` is re-evaluated on every mouse move rather than captured
    /// once, since the panel's frame can change (repositioning, screen changes) while a HUD is
    /// visible.
    func start(trackingFrame frameProvider: @escaping () -> NSRect) {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self else { return }
            if frameProvider().contains(NSEvent.mouseLocation) {
                self.onEnter()
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit { stop() }
}
