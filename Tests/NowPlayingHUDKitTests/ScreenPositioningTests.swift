import Foundation
import NowPlayingHUDKit

private func standardScreen(
    id: String = "main", originX: CGFloat = 0, originY: CGFloat = 0,
    width: CGFloat = 1920, height: CGFloat = 1080,
    menuBarHeight: CGFloat = 24, dockHeight: CGFloat = 60,
    notchInset: CGFloat = 0, backingScaleFactor: CGFloat = 2
) -> ScreenSnapshot {
    let frame = CGRect(x: originX, y: originY, width: width, height: height)
    let visibleFrame = CGRect(
        x: originX, y: originY + dockHeight,
        width: width, height: height - menuBarHeight - dockHeight
    )
    var leftAux: CGRect?
    var rightAux: CGRect?
    if notchInset > 0 {
        leftAux = CGRect(x: originX, y: originY + height - notchInset, width: width * 0.35, height: notchInset)
        rightAux = CGRect(x: originX + width * 0.65, y: originY + height - notchInset, width: width * 0.35, height: notchInset)
    }
    return ScreenSnapshot(
        id: id, frame: frame, visibleFrame: visibleFrame, safeAreaInsetTop: notchInset,
        auxiliaryTopLeftArea: leftAux, auxiliaryTopRightArea: rightAux, backingScaleFactor: backingScaleFactor
    )
}

func registerScreenPositioningTests(on runner: TestRunner) {
    let hudSize = CGSize(width: 320, height: 80)

    runner.suite("ScreenPositioningService") {
        runner.test("topCenter is horizontally centered and near the top of visibleFrame") {
            let screen = standardScreen()
            let frame = ScreenPositioningService.frame(for: hudSize, position: .topCenter, edgeOffset: 12, on: screen)
            try expect(abs(frame.midX - screen.visibleFrame.midX) < 0.5)
            try expect(abs(frame.maxY - (screen.visibleFrame.maxY - 12)) < 0.5)
        }

        runner.test("bottomCenter sits near the bottom of visibleFrame") {
            let screen = standardScreen()
            let frame = ScreenPositioningService.frame(for: hudSize, position: .bottomCenter, edgeOffset: 12, on: screen)
            try expect(abs(frame.midX - screen.visibleFrame.midX) < 0.5)
            try expect(abs(frame.minY - (screen.visibleFrame.minY + 12)) < 0.5)
        }

        runner.test("topLeft and topRight anchor to opposite edges") {
            let screen = standardScreen()
            let left = ScreenPositioningService.frame(for: hudSize, position: .topLeft, edgeOffset: 10, on: screen)
            let right = ScreenPositioningService.frame(for: hudSize, position: .topRight, edgeOffset: 10, on: screen)
            try expect(abs(left.minX - (screen.visibleFrame.minX + 10)) < 0.5)
            try expect(abs(right.maxX - (screen.visibleFrame.maxX - 10)) < 0.5)
        }

        runner.test("bottomLeft and bottomRight anchor to opposite edges") {
            let screen = standardScreen()
            let left = ScreenPositioningService.frame(for: hudSize, position: .bottomLeft, edgeOffset: 10, on: screen)
            let right = ScreenPositioningService.frame(for: hudSize, position: .bottomRight, edgeOffset: 10, on: screen)
            try expect(abs(left.minX - (screen.visibleFrame.minX + 10)) < 0.5)
            try expect(abs(right.maxX - (screen.visibleFrame.maxX - 10)) < 0.5)
        }

        runner.test("smartTopCenter degrades to topCenter on a notchless display") {
            let screen = standardScreen(notchInset: 0)
            let smart = ScreenPositioningService.frame(for: hudSize, position: .smartTopCenter, edgeOffset: 12, on: screen)
            let plain = ScreenPositioningService.frame(for: hudSize, position: .topCenter, edgeOffset: 12, on: screen)
            try expect(smart == plain)
        }

        runner.test("smartTopCenter tucks below the notch, centered on screen, on a notched display") {
            let screen = standardScreen(notchInset: 32)
            let frame = ScreenPositioningService.frame(for: hudSize, position: .smartTopCenter, edgeOffset: 8, on: screen)
            try expect(abs(frame.midX - screen.frame.midX) < 0.5, "should be centered on the physical notch, i.e. the screen")
            try expect(frame.maxY <= screen.notchBottomY, "must not sit under the camera housing")
            try expect(frame.maxY > screen.visibleFrame.maxY - 32, "should hug just below the notch, not fall back to plain top-center")
        }

        runner.test("negative-origin display (positioned above/left of main) positions correctly") {
            // A secondary display up and to the left of the main display at (0,0) — a common
            // multi-monitor arrangement macOS represents with negative coordinates.
            let screen = standardScreen(id: "secondary", originX: -1920, originY: 200, width: 1920, height: 1080)
            let frame = ScreenPositioningService.frame(for: hudSize, position: .topCenter, edgeOffset: 12, on: screen)
            try expect(frame.midX < 0, "center should land within the negative-origin screen's own bounds")
            try expect(abs(frame.midX - screen.visibleFrame.midX) < 0.5)
        }

        runner.test("result is rounded to whole backing pixels at 2x scale") {
            // An edge offset chosen to force a fractional midpoint before rounding.
            let screen = standardScreen(width: 1921, backingScaleFactor: 2)
            let frame = ScreenPositioningService.frame(for: hudSize, position: .topCenter, edgeOffset: 12, on: screen)
            let scaledX = frame.origin.x * 2
            try expect(abs(scaledX - scaledX.rounded()) < 0.0001, "x origin should land exactly on a backing pixel")
        }

        runner.test("a HUD wider than the visible frame is clamped to fit, never overflowing") {
            let screen = standardScreen(width: 200, height: 200)
            let hugeSize = CGSize(width: 500, height: 60)
            let frame = ScreenPositioningService.frame(for: hugeSize, position: .topCenter, edgeOffset: 12, on: screen)
            try expect(frame.minX >= screen.visibleFrame.minX)
            try expect(frame.maxX <= screen.visibleFrame.maxX)
            try expect(frame.width <= screen.visibleFrame.width)
        }

        runner.test("edge offset is respected across a range of values") {
            let screen = standardScreen()
            for offset: CGFloat in [0, 4, 24, 48] {
                let frame = ScreenPositioningService.frame(for: hudSize, position: .topCenter, edgeOffset: offset, on: screen)
                try expect(abs((screen.visibleFrame.maxY - frame.maxY) - offset) < 0.5, "offset \(offset) not respected")
            }
        }
    }
}
