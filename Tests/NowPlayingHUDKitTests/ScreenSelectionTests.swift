import Foundation
import NowPlayingHUDKit

private func screen(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat = 1920, h: CGFloat = 1080) -> ScreenSnapshot {
    ScreenSnapshot(
        id: id, frame: CGRect(x: x, y: y, width: w, height: h),
        visibleFrame: CGRect(x: x, y: y, width: w, height: h - 24),
        safeAreaInsetTop: 0, auxiliaryTopLeftArea: nil, auxiliaryTopRightArea: nil, backingScaleFactor: 2
    )
}

func registerScreenSelectionTests(on runner: TestRunner) {
    runner.suite("ScreenSelection") {
        runner.test("mainDisplay behavior picks the screen matching mainDisplayID") {
            let main = screen("main", x: 0, y: 0)
            let secondary = screen("secondary", x: 1920, y: 0)
            let result = ScreenSelection.selectScreens(
                behavior: .mainDisplay, selectedDisplayID: nil, mouseLocation: .zero,
                screens: [secondary, main], mainDisplayID: "main"
            )
            try expect(result.map(\.id) == ["main"])
        }

        runner.test("displayWithMouse picks the screen containing the pointer, including a negative-origin screen") {
            let main = screen("main", x: 0, y: 0)
            let leftOfMain = screen("left", x: -1920, y: 0)
            let mouse = CGPoint(x: -960, y: 500) // inside the negative-origin screen
            let result = ScreenSelection.selectScreens(
                behavior: .displayWithMouse, selectedDisplayID: nil, mouseLocation: mouse,
                screens: [main, leftOfMain], mainDisplayID: "main"
            )
            try expect(result.map(\.id) == ["left"])
        }

        runner.test("displayWithMouse falls back to main when the pointer is on no known screen") {
            let main = screen("main", x: 0, y: 0)
            let result = ScreenSelection.selectScreens(
                behavior: .displayWithMouse, selectedDisplayID: nil, mouseLocation: CGPoint(x: 99999, y: 99999),
                screens: [main], mainDisplayID: "main"
            )
            try expect(result.map(\.id) == ["main"])
        }

        runner.test("selectedDisplay picks the exact matching screen") {
            let main = screen("main", x: 0, y: 0)
            let secondary = screen("secondary", x: 1920, y: 0)
            let result = ScreenSelection.selectScreens(
                behavior: .selectedDisplay, selectedDisplayID: "secondary", mouseLocation: .zero,
                screens: [main, secondary], mainDisplayID: "main"
            )
            try expect(result.map(\.id) == ["secondary"])
        }

        runner.test("selectedDisplay gracefully falls back to main when the chosen display disconnected") {
            let main = screen("main", x: 0, y: 0)
            let result = ScreenSelection.selectScreens(
                behavior: .selectedDisplay, selectedDisplayID: "no-longer-connected", mouseLocation: .zero,
                screens: [main], mainDisplayID: "main"
            )
            try expect(result.map(\.id) == ["main"])
        }

        runner.test("allDisplays returns every screen") {
            let main = screen("main", x: 0, y: 0)
            let secondary = screen("secondary", x: 1920, y: 0)
            let result = ScreenSelection.selectScreens(
                behavior: .allDisplays, selectedDisplayID: nil, mouseLocation: .zero,
                screens: [main, secondary], mainDisplayID: "main"
            )
            try expect(Set(result.map(\.id)) == Set(["main", "secondary"]))
        }

        runner.test("no screens at all returns an empty array rather than crashing") {
            let result = ScreenSelection.selectScreens(
                behavior: .mainDisplay, selectedDisplayID: nil, mouseLocation: .zero,
                screens: [], mainDisplayID: "main"
            )
            try expect(result.isEmpty)
        }

        runner.test("unknown mainDisplayID falls back to the first available screen") {
            let only = screen("only", x: 0, y: 0)
            let result = ScreenSelection.selectScreens(
                behavior: .mainDisplay, selectedDisplayID: nil, mouseLocation: .zero,
                screens: [only], mainDisplayID: nil
            )
            try expect(result.map(\.id) == ["only"])
        }
    }
}
