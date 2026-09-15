import Foundation
import CoreServices
import AppKit
import os

/// The Automation (Apple Events) permission state for one target application, as reported by
/// `AEDeterminePermissionToAutomateTarget`.
public enum AutomationStatus: Sendable, Equatable {
    /// Never asked — no verdict exists yet in TCC. The first real user-initiated command will
    /// trigger the system's own consent dialog.
    case notDetermined
    case authorized
    case denied
    /// The target application isn't currently running, so permission can't be determined yet.
    case targetNotRunning
    case unknown(OSStatus)

    public var isUsable: Bool { self == .authorized }
}

/// Reads (and, only on genuine user-initiated action, triggers) Automation permission for a
/// target application, without ever spamming the system consent dialog.
///
/// `AEDeterminePermissionToAutomateTarget(askUserIfNeeded: false)` performs a **read-only**
/// check — it never prompts — which is what powers the Settings status readout and periodic
/// silent re-checks. A prompt is only ever triggered by an actual Apple Event sent as a direct
/// result of the user pressing a button (play/pause, "Test Spotify Connection", etc.), and a
/// denial is remembered so we don't re-trigger the OS's own "keep asking" behavior more than
/// necessary.
public final class AutomationPermissionService: @unchecked Sendable {
    public static let shared = AutomationPermissionService()

    /// What a real Apple Event just told us, per player — keyed on ground truth rather than the
    /// read-only OS query below, which was observed empirically (on an ad-hoc-signed build) to
    /// keep reporting `.notDetermined` indefinitely even while genuine Apple Events to the same
    /// target were succeeding in milliseconds. Providers call `recordObservedResult` immediately
    /// after every real `AppleEventBridge` round trip, so this always reflects what actually just
    /// happened rather than a system API that doesn't seem to track this app's true grant.
    private let observed = OSAllocatedUnfairLock<[PlayerIdentifier: AutomationStatus]>(initialState: [:])

    private init() {}

    /// Status to show the user. Prefers a real, freshly-observed outcome; falls back to the
    /// OS's own (sometimes stale) read-only check only when we have no observation yet — e.g.
    /// before the very first Apple Event this launch has attempted.
    public func status(for player: PlayerIdentifier) -> AutomationStatus {
        guard isRunning(player) else { return .targetNotRunning }
        if let observedStatus = observed.withLock({ $0[player] }) {
            return observedStatus
        }
        return systemStatus(for: player)
    }

    /// The non-prompting `AEDeterminePermissionToAutomateTarget` read, kept as a fallback and for
    /// diagnostics, but no longer trusted as the sole source of truth — see `observed` above.
    private func systemStatus(for player: PlayerIdentifier) -> AutomationStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: player.bundleIdentifier)
        let result = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false)

        switch Int(result) {
        case 0:
            return .authorized
        case -1743: // errAEEventNotPermitted
            return .denied
        case -1744: // errAEEventWouldRequireUserConsent
            return .notDetermined
        case -600: // procNotFound
            return .targetNotRunning
        default:
            return .unknown(result)
        }
    }

    /// Called by a provider immediately after a real Apple Event completes. Only genuine success
    /// and genuine `errAEEventNotPermitted` denials are recorded — a timeout or unrelated error
    /// leaves the previous observation alone, since neither actually tells us the grant changed.
    public func recordObservedResult(for player: PlayerIdentifier, outcome: AutomationStatus) {
        guard outcome == .authorized || outcome == .denied else { return }
        observed.withLock { $0[player] = outcome }
    }

    private func isRunning(_ player: PlayerIdentifier) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == player.bundleIdentifier
        }
    }

    /// Opens System Settings directly to the Automation pane so a denied user can fix it in one
    /// click, per the "tell them where to fix it" requirement.
    public func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
