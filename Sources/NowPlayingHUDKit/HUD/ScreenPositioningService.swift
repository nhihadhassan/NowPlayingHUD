import Foundation
import CoreGraphics

/// Pure geometry: where the HUD panel's frame should be, given a position preference, the HUD's
/// own size, an edge offset, and one screen's snapshot. No `NSScreen`/`NSWindow` involved, so
/// every position — including notch-aware placement, negative-origin displays, and Retina
/// rounding — is directly unit-testable.
public enum ScreenPositioningService {
    private enum HorizontalAnchor { case leading, center, trailing }

    public static func frame(
        for size: CGSize, position: HUDPosition, edgeOffset: CGFloat, on screen: ScreenSnapshot
    ) -> CGRect {
        let raw: CGRect
        switch position {
        case .smartTopCenter:
            raw = smartTopCenterFrame(for: size, edgeOffset: edgeOffset, on: screen)
        case .topCenter:
            raw = topAnchored(for: size, edgeOffset: edgeOffset, on: screen, anchor: .center)
        case .topLeft:
            raw = topAnchored(for: size, edgeOffset: edgeOffset, on: screen, anchor: .leading)
        case .topRight:
            raw = topAnchored(for: size, edgeOffset: edgeOffset, on: screen, anchor: .trailing)
        case .bottomCenter:
            raw = bottomAnchored(for: size, edgeOffset: edgeOffset, on: screen, anchor: .center)
        case .bottomLeft:
            raw = bottomAnchored(for: size, edgeOffset: edgeOffset, on: screen, anchor: .leading)
        case .bottomRight:
            raw = bottomAnchored(for: size, edgeOffset: edgeOffset, on: screen, anchor: .trailing)
        }
        return clamped(raw, to: screen.visibleFrame, backingScaleFactor: screen.backingScaleFactor)
    }

    /// Below/around a notch when one exists (kept clear of the camera housing horizontally by
    /// virtue of being centered on the screen, since a physical notch is itself centered); plain
    /// top-center on any display without one.
    private static func smartTopCenterFrame(for size: CGSize, edgeOffset: CGFloat, on screen: ScreenSnapshot) -> CGRect {
        guard screen.hasNotch else {
            return topAnchored(for: size, edgeOffset: edgeOffset, on: screen, anchor: .center)
        }
        let x = screen.frame.midX - size.width / 2
        let y = screen.notchBottomY - size.height - edgeOffset
        // Never let notch math (e.g. an unusually large inset) push the HUD above the ordinary
        // visible frame's top — fall back to the plain top-anchored position in that case.
        let fallbackY = screen.visibleFrame.maxY - size.height - edgeOffset
        return CGRect(x: x, y: min(y, fallbackY), width: size.width, height: size.height)
    }

    private static func topAnchored(for size: CGSize, edgeOffset: CGFloat, on screen: ScreenSnapshot, anchor: HorizontalAnchor) -> CGRect {
        CGRect(
            x: xOrigin(for: anchor, size: size, edgeOffset: edgeOffset, in: screen.visibleFrame),
            y: screen.visibleFrame.maxY - size.height - edgeOffset,
            width: size.width, height: size.height
        )
    }

    private static func bottomAnchored(for size: CGSize, edgeOffset: CGFloat, on screen: ScreenSnapshot, anchor: HorizontalAnchor) -> CGRect {
        CGRect(
            x: xOrigin(for: anchor, size: size, edgeOffset: edgeOffset, in: screen.visibleFrame),
            y: screen.visibleFrame.minY + edgeOffset,
            width: size.width, height: size.height
        )
    }

    private static func xOrigin(for anchor: HorizontalAnchor, size: CGSize, edgeOffset: CGFloat, in visibleFrame: CGRect) -> CGFloat {
        switch anchor {
        case .leading: return visibleFrame.minX + edgeOffset
        case .center: return visibleFrame.midX - size.width / 2
        case .trailing: return visibleFrame.maxX - size.width - edgeOffset
        }
    }

    /// Keeps the frame fully within `visibleFrame` (defensive against pathological edge offsets
    /// or a HUD wider than the screen) and rounds to whole backing pixels so edges stay crisp on
    /// Retina displays rather than landing on a half-pixel boundary.
    private static func clamped(_ frame: CGRect, to visibleFrame: CGRect, backingScaleFactor: CGFloat) -> CGRect {
        var x = frame.origin.x
        var y = frame.origin.y
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)

        x = max(visibleFrame.minX, min(x, visibleFrame.maxX - width))
        y = max(visibleFrame.minY, min(y, visibleFrame.maxY - height))

        let scale = max(backingScaleFactor, 1)
        x = (x * scale).rounded() / scale
        y = (y * scale).rounded() / scale

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
