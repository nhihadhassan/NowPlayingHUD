import Foundation

/// The HUD's presentation lifecycle, as a pure, side-effect-free state machine.
///
/// This deliberately has no AppKit/timer/animation code in it at all — `handle(_:)` takes an
/// event and returns the list of `Action`s the caller (`HUDPresentationCoordinator`) should
/// perform, so every guarantee in the spec (exactly one HUD ever exists, a new track while
/// visible updates in place and restarts the timer, hover suspends dismissal and resumes it
/// after a grace delay) is directly unit-testable without a real window, timer, or screen.
///
/// Only two real on-screen phases are tracked (`shown(hovering:)` rather than the originally
/// sketched five-state list) — whether a fresh entrance animation or an in-place content update
/// is needed is expressed by *which* `Action` a transition emits, not by a separate phase. This
/// is a simplification made during implementation; it preserves every behavior the five-state
/// sketch was meant to guarantee with less incidental complexity.
public struct HUDStateMachine: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case hidden
        case shown(hovering: Bool)
    }

    public enum Event: Sendable, Equatable {
        /// A track/state change significant enough to show or update the HUD. Policy about
        /// *whether* a given change should reach the HUD at all (automatic HUD enabled? "show on
        /// pause" on?) is decided by the coordinator before this is sent — the state machine
        /// assumes every `.significantChange` it receives should be acted on.
        case significantChange
        case pointerEntered
        case pointerExited
        case dismissalTimerFired
        case hoverGraceTimerFired
        case manualShow
        case manualDismiss
        /// Automatic HUD disabled, Spotify quit, app quitting, etc. — hide with no animation.
        case forceHide
    }

    public enum Action: Sendable, Equatable {
        /// Panel wasn't on screen: animate its whole-panel entrance.
        case presentFresh
        /// Panel already on screen: crossfade the content that changed, don't replay the
        /// entrance animation.
        case updateInPlace
        case restartDismissalTimer
        case cancelDismissalTimer
        case startHoverGraceTimer
        case cancelHoverGraceTimer
        case playExitAnimationThenHide
        case hideImmediately
    }

    public private(set) var phase: Phase = .hidden

    public init() {}

    public mutating func handle(_ event: Event) -> [Action] {
        switch (phase, event) {

        // MARK: hidden
        case (.hidden, .significantChange), (.hidden, .manualShow):
            phase = .shown(hovering: false)
            return [.presentFresh, .restartDismissalTimer]

        case (.hidden, _):
            return [] // stale/duplicate event (e.g. a timer racing a manual dismiss) — ignore.

        // MARK: shown, not hovering
        case (.shown(hovering: false), .significantChange):
            return [.updateInPlace, .restartDismissalTimer]

        case (.shown(hovering: false), .pointerEntered):
            phase = .shown(hovering: true)
            return [.cancelDismissalTimer]

        case (.shown(hovering: false), .pointerExited):
            return [] // already not hovering — a redundant/stale exit event; nothing to do.

        case (.shown(hovering: false), .dismissalTimerFired):
            phase = .hidden
            return [.playExitAnimationThenHide]

        case (.shown(hovering: false), .manualShow):
            // Already shown; a repeated manual "Show HUD" just restarts the clock.
            return [.restartDismissalTimer]

        // MARK: shown, hovering
        case (.shown(hovering: true), .significantChange):
            // Content still updates live while hovered; dismissal stays suspended.
            return [.updateInPlace]

        case (.shown(hovering: true), .pointerExited):
            phase = .shown(hovering: false)
            return [.startHoverGraceTimer]

        case (.shown(hovering: true), .dismissalTimerFired), (.shown(hovering: true), .hoverGraceTimerFired):
            return [] // stale timer racing a re-entry — ignore, we're still hovering.

        case (.shown(hovering: true), .pointerEntered):
            return [] // already hovering; nothing to do.

        case (.shown(hovering: true), .manualShow):
            return []

        // MARK: shown, either hover state
        case (.shown, .hoverGraceTimerFired):
            // Grace period elapsed without the pointer returning: dismiss now, rather than
            // starting a whole fresh countdown — the HUD has already had its full visible time.
            phase = .hidden
            return [.playExitAnimationThenHide]

        case (.shown, .manualDismiss):
            phase = .hidden
            return [.cancelDismissalTimer, .cancelHoverGraceTimer, .playExitAnimationThenHide]

        case (.shown, .forceHide):
            phase = .hidden
            return [.cancelDismissalTimer, .cancelHoverGraceTimer, .hideImmediately]
        }
    }
}
