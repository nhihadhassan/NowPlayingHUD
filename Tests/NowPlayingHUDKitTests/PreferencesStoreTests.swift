import Foundation
import NowPlayingHUDKit

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "com.nowplayinghud.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

func registerPreferencesStoreTests(on runner: TestRunner) {
    runner.suite("PreferencesStore persistence") {
        runner.test("defaults are sensible on first launch") {
            let store = PreferencesStore(defaults: isolatedDefaults())
            try expect(store.automaticHUDEnabled)
            try expect(store.hudPosition == .smartTopCenter)
            try expect(store.monitorBehavior == .displayWithMouse)
            try expect(store.hideWhenPlayerFrontmost)
            try expect(store.showOverFullScreenApps)
            try expect(store.shortcutBindings.isEmpty, "no shortcut should be bound by default")
        }

        runner.test("a changed value round-trips through a fresh store instance") {
            let defaults = isolatedDefaults()
            let first = PreferencesStore(defaults: defaults)
            first.hudPosition = .bottomLeft
            first.displayDurationSeconds = 5.5
            first.hudStyle = .minimal
            first.playerSelectionMode = .appleMusic

            let second = PreferencesStore(defaults: defaults)
            try expect(second.hudPosition == .bottomLeft)
            try expect(second.displayDurationSeconds == 5.5)
            try expect(second.hudStyle == .minimal)
            try expect(second.playerSelectionMode == .appleMusic)
        }

        runner.test("shortcut bindings round-trip, including unbinding") {
            let defaults = isolatedDefaults()
            let first = PreferencesStore(defaults: defaults)
            first.shortcutBindings = [
                .playPause: KeyCombo(keyCode: 35, carbonModifiers: 0x0100_0000),
                .next: KeyCombo(keyCode: 37, carbonModifiers: 0x0008_0000)
            ]

            let second = PreferencesStore(defaults: defaults)
            try expect(second.shortcutBindings[.playPause]?.keyCode == 35)
            try expect(second.shortcutBindings[.next]?.keyCode == 37)
            try expect(second.shortcutBindings[.toggleHUD] == nil)

            second.shortcutBindings.removeValue(forKey: .playPause)
            let third = PreferencesStore(defaults: defaults)
            try expect(third.shortcutBindings[.playPause] == nil, "unbinding should persist")
            try expect(third.shortcutBindings[.next] != nil)
        }

        runner.test("two independent suites do not leak into each other") {
            let storeA = PreferencesStore(defaults: isolatedDefaults())
            let storeB = PreferencesStore(defaults: isolatedDefaults())
            storeA.hudPosition = .topRight
            try expect(storeB.hudPosition == .smartTopCenter, "unrelated store must be unaffected")
        }
    }
}
