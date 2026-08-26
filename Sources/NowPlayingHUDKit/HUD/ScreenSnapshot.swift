import Foundation
import CoreGraphics

/// A pure-value snapshot of one `NSScreen`'s geometry, decoupled from AppKit so
/// `ScreenPositioningService`'s math is directly unit-testable with synthetic multi-display and
/// notch configurations — no real hardware, and no `NSScreen` calls, required.
public struct ScreenSnapshot: Sendable, Equatable, Identifiable {
    /// A stable per-display identifier (backed by `CGDirectDisplayID` in production), used to
    /// remember a user's "selected display" choice and to detect the main display.
    public let id: String
    /// The display's full frame, in the *global* AppKit coordinate space — critically, this can
    /// have a negative origin for a display positioned above/left of the main display, and must
    /// never be assumed to start at (0, 0).
    public let frame: CGRect
    /// `frame` minus the menu bar and Dock (whichever edges they occupy).
    public let visibleFrame: CGRect
    /// Insets from `frame` describing hardware-obstructed area — non-zero `top` indicates a
    /// camera-housing/notch display.
    public let safeAreaInsetTop: CGFloat
    /// The usable menu-bar-height strip to the left of a notch, if this screen has one and
    /// something occupies space there (usually just menu bar items) — `nil` on a notchless
    /// display, or one where nothing constrains the full width.
    public let auxiliaryTopLeftArea: CGRect?
    /// The usable menu-bar-height strip to the right of a notch.
    public let auxiliaryTopRightArea: CGRect?
    public let backingScaleFactor: CGFloat

    public init(
        id: String, frame: CGRect, visibleFrame: CGRect, safeAreaInsetTop: CGFloat,
        auxiliaryTopLeftArea: CGRect?, auxiliaryTopRightArea: CGRect?, backingScaleFactor: CGFloat
    ) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaInsetTop = safeAreaInsetTop
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
        self.backingScaleFactor = backingScaleFactor
    }

    /// Whether this display has a camera housing/notch. Derived purely from the public
    /// `safeAreaInsets`/`auxiliaryTop*Area` APIs — no model name or hardcoded notch dimensions.
    public var hasNotch: Bool { safeAreaInsetTop > 0 }

    /// The Y coordinate (global AppKit space) of the notch's bottom edge — i.e. where content
    /// can safely begin without sitting under the camera housing. Meaningless when `hasNotch`
    /// is false.
    public var notchBottomY: CGFloat { frame.maxY - safeAreaInsetTop }
}
