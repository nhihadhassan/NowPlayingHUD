import Foundation

/// Everything the HUD's SwiftUI content needs to ask of the outside world, without depending on
/// `PlaybackCoordinator`/`HUDPresentationCoordinator` directly — keeps the view layer testable
/// and reusable (the same protocol backs the menu bar mini player).
@MainActor
public protocol HUDInteracting: AnyObject {
    func perform(_ command: PlaybackCommand)
    func openInPlayer()
    func copyTrackLink()
    func copyTrackAndArtist()
    /// Called when the pointer enters/exits the HUD's content — the authoritative signal once
    /// the panel is interactive; `HUDHoverTracker` only handles the initial click-through entry.
    func hoverStateChanged(isHovering: Bool)
    func primaryClickTriggered()
    func dismissRequested()
}
