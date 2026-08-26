import AppKit
import Foundation
import ServiceManagement

/// Launch at Login via the modern `SMAppService` API (macOS 13+) — no legacy
/// `SMLoginItemSetEnabled`/helper-app hacks. `SMAppService` requires the app be code-signed
/// (ad-hoc signing, as this project's `make app` does, satisfies that); see README "Gatekeeper
/// and signing" for what that means for a personal local build.
public enum LaunchAtLoginController {
    public enum Status: Sendable, Equatable {
        case disabled
        case enabled
        /// Registered, but the user needs to approve it in System Settings → General → Login
        /// Items — surfaced distinctly so Settings can explain rather than silently no-op.
        case requiresApproval
        case unsupported
    }

    public static var status: Status {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .disabled
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unsupported
        @unknown default: return .unsupported
        }
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Result<Void, Error> {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Deep link to the Login Items pane, for the `.requiresApproval` case.
    public static func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
