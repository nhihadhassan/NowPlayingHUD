import Foundation
import CoreGraphics

/// Pure decision logic for "which display(s) get the HUD", independent of `NSScreen` so
/// disconnect-fallback and mouse-follow behavior are unit-testable with synthetic screen lists.
public enum ScreenSelection {
    /// The screen(s) that should receive the HUD right now. Returns more than one element only
    /// for `.allDisplays`. Returns an empty array if there are no screens at all (defensive;
    /// shouldn't happen in practice).
    public static func selectScreens(
        behavior: MonitorBehavior,
        selectedDisplayID: String?,
        mouseLocation: CGPoint,
        screens: [ScreenSnapshot],
        mainDisplayID: String?
    ) -> [ScreenSnapshot] {
        guard !screens.isEmpty else { return [] }

        switch behavior {
        case .allDisplays:
            return screens

        case .mainDisplay:
            return [mainScreen(screens: screens, mainDisplayID: mainDisplayID)]

        case .selectedDisplay:
            if let selectedDisplayID, let match = screens.first(where: { $0.id == selectedDisplayID }) {
                return [match]
            }
            // The previously-selected display disconnected: fall back gracefully to main.
            return [mainScreen(screens: screens, mainDisplayID: mainDisplayID)]

        case .displayWithMouse:
            if let match = screens.first(where: { $0.frame.contains(mouseLocation) }) {
                return [match]
            }
            return [mainScreen(screens: screens, mainDisplayID: mainDisplayID)]
        }
    }

    private static func mainScreen(screens: [ScreenSnapshot], mainDisplayID: String?) -> ScreenSnapshot {
        if let mainDisplayID, let match = screens.first(where: { $0.id == mainDisplayID }) {
            return match
        }
        return screens[0]
    }
}
