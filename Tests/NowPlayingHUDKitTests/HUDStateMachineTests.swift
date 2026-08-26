import Foundation
import NowPlayingHUDKit

func registerHUDStateMachineTests(on runner: TestRunner) {
    runner.suite("HUDStateMachine") {
        runner.test("starts hidden") {
            let machine = HUDStateMachine()
            try expect(machine.phase == .hidden)
        }

        runner.test("first significant change presents fresh and starts the timer") {
            var machine = HUDStateMachine()
            let actions = machine.handle(.significantChange)
            try expect(actions == [.presentFresh, .restartDismissalTimer])
            try expect(machine.phase == .shown(hovering: false))
        }

        runner.test("a second track while visible updates in place, never presents a second panel") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            let actions = machine.handle(.significantChange)
            try expect(actions == [.updateInPlace, .restartDismissalTimer])
            try expect(!actions.contains(.presentFresh), "must never re-present — exactly one HUD ever exists")
        }

        // The scenario from the spec: skipping through five songs rapidly should still leave
        // exactly one HUD, updated in place each time, never a second panel.
        runner.test("rapid skip through five tracks presents exactly once") {
            var machine = HUDStateMachine()
            var presentFreshCount = 0
            var updateInPlaceCount = 0
            for _ in 0..<5 {
                for action in machine.handle(.significantChange) {
                    if action == .presentFresh { presentFreshCount += 1 }
                    if action == .updateInPlace { updateInPlaceCount += 1 }
                }
            }
            try expect(presentFreshCount == 1, "expected exactly one presentFresh, got \(presentFreshCount)")
            try expect(updateInPlaceCount == 4, "expected 4 in-place updates for tracks 2-5, got \(updateInPlaceCount)")
        }

        runner.test("dismissal timer firing while not hovering hides the HUD") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            let actions = machine.handle(.dismissalTimerFired)
            try expect(actions == [.playExitAnimationThenHide])
            try expect(machine.phase == .hidden)
        }

        runner.test("hover suspends the dismissal timer") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            let actions = machine.handle(.pointerEntered)
            try expect(actions == [.cancelDismissalTimer, .cancelHoverGraceTimer])
            try expect(machine.phase == .shown(hovering: true))
        }

        runner.test("a stale dismissal timer firing while hovering is ignored") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            _ = machine.handle(.pointerEntered)
            let actions = machine.handle(.dismissalTimerFired)
            try expect(actions.isEmpty)
            try expect(machine.phase == .shown(hovering: true), "must still be shown and hovering")
        }

        runner.test("pointer exit starts the hover grace timer rather than dismissing immediately") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            _ = machine.handle(.pointerEntered)
            let actions = machine.handle(.pointerExited)
            try expect(actions == [.startHoverGraceTimer])
            try expect(machine.phase == .shown(hovering: false))
        }

        runner.test("grace timer elapsing without re-entry dismisses the HUD") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            _ = machine.handle(.pointerEntered)
            _ = machine.handle(.pointerExited)
            let actions = machine.handle(.hoverGraceTimerFired)
            try expect(actions == [.playExitAnimationThenHide])
            try expect(machine.phase == .hidden)
        }

        runner.test("re-entering during the grace period cancels the pending dismissal") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            _ = machine.handle(.pointerEntered)
            _ = machine.handle(.pointerExited) // grace timer conceptually running
            let actions = machine.handle(.pointerEntered) // pointer comes back before it fires
            try expect(actions == [.cancelDismissalTimer, .cancelHoverGraceTimer])
            try expect(machine.phase == .shown(hovering: true))
            // A stale grace timer firing after this should now be ignored.
            try expect(machine.handle(.hoverGraceTimerFired).isEmpty)
            try expect(machine.phase == .shown(hovering: true))
        }

        runner.test("content keeps updating live while hovering, without restarting a (suspended) timer") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            _ = machine.handle(.pointerEntered)
            let actions = machine.handle(.significantChange)
            try expect(actions == [.updateInPlace])
        }

        runner.test("manual show while hidden presents and starts the timer") {
            var machine = HUDStateMachine()
            let actions = machine.handle(.manualShow)
            try expect(actions == [.presentFresh, .restartDismissalTimer])
            try expect(machine.phase == .shown(hovering: false))
        }

        runner.test("manual show while already visible just restarts the timer") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            let actions = machine.handle(.manualShow)
            try expect(actions == [.restartDismissalTimer])
        }

        runner.test("manual dismiss cancels timers and hides") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            let actions = machine.handle(.manualDismiss)
            try expect(actions.contains(.playExitAnimationThenHide))
            try expect(actions.contains(.cancelDismissalTimer))
            try expect(machine.phase == .hidden)
        }

        runner.test("forceHide hides immediately without an exit animation, even while hovering") {
            var machine = HUDStateMachine()
            _ = machine.handle(.significantChange)
            _ = machine.handle(.pointerEntered)
            let actions = machine.handle(.forceHide)
            try expect(actions.contains(.hideImmediately))
            try expect(!actions.contains(.playExitAnimationThenHide))
            try expect(machine.phase == .hidden)
        }

        runner.test("stale events while hidden are all safely ignored") {
            var machine = HUDStateMachine()
            for event: HUDStateMachine.Event in [.pointerEntered, .pointerExited, .dismissalTimerFired, .hoverGraceTimerFired, .manualDismiss, .forceHide] {
                let actions = machine.handle(event)
                try expect(actions.isEmpty, "expected no actions for stale event \(event) while hidden")
                try expect(machine.phase == .hidden)
            }
        }
    }
}
