import Foundation
import CoreServices
import AppKit

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

    private init() {}

    /// Non-prompting status check. Safe to call frequently (e.g. each time Settings appears).
    public func status(for player: PlayerIdentifier) -> AutomationStatus {
        guard isRunning(player) else { return .targetNotRunning }

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
