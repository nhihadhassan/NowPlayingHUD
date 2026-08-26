import Foundation
import os

/// Executes AppleScript against a target application entirely **in-process** — no `osascript`
/// process spawning, no ScriptingBridge (its generated bindings need `sdp`, an Xcode-only tool
/// unavailable on a Command-Line-Tools-only machine, and Spotify's own scripting dictionary
/// assigns "shuffling enabled" and "repeating enabled" the same four-char code, `pReE`, which
/// would make an auto-generated binding actively misleading).
///
/// Every script is wrapped in AppleScript's own `with timeout of <n> seconds ... end timeout`.
/// This was verified empirically against a real, momentarily-unresponsive Spotify: it returned
/// error `-1712` ("AppleEvent timed out") promptly at the requested deadline, rather than hanging
/// for the (much longer) system default. A second, slightly longer deadline runs on an
/// independent queue purely as a safety net for a caller, in case the inner timeout construct
/// ever fails to fire — it guarantees `run(_:)` always returns in bounded time even then, though
/// in that pathological case the dedicated execution queue itself would remain blocked for any
/// calls still ahead of it.
///
/// All execution happens on a dedicated serial `DispatchQueue`, never on the main thread or
/// Swift's shared cooperative thread pool, so a slow Apple Event can never stall UI or other
/// concurrent work.
public final class AppleEventBridge: @unchecked Sendable {
    public struct ScriptError: Error, Sendable, Equatable {
        public let code: Int
        public let message: String

        public static func == (lhs: ScriptError, rhs: ScriptError) -> Bool {
            lhs.code == rhs.code
        }
    }

    private let queue: DispatchQueue
    private let defaultTimeout: TimeInterval

    public init(label: String, defaultTimeout: TimeInterval = 2.0) {
        self.queue = DispatchQueue(label: label, qos: .userInitiated)
        self.defaultTimeout = defaultTimeout
    }

    /// Compiles and runs `source` (already inside an implicit `tell application` block or
    /// otherwise self-contained), returning the resulting `NSAppleEventDescriptor`.
    ///
    /// - Important: `source` must never interpolate untrusted or arbitrary string content
    ///   (track titles, artist names, etc.) — every call site in this app only interpolates
    ///   numbers and booleans it generated itself, so there is no AppleScript-injection surface.
    @discardableResult
    public func run(_ source: String, timeout: TimeInterval? = nil) async throws -> NSAppleEventDescriptor {
        let effectiveTimeout = timeout ?? defaultTimeout
        let wrapped = "with timeout of \(max(1, Int(effectiveTimeout.rounded(.up)))) seconds\n\(source)\nend timeout"
        let outerDeadline: TimeInterval = effectiveTimeout + 2.0

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSAppleEventDescriptor, Error>) in
            let resumed = OSAllocatedUnfairLock(initialState: false)

            func finish(_ body: () -> Void) {
                let alreadyResumed = resumed.withLock { state -> Bool in
                    let was = state
                    state = true
                    return was
                }
                guard !alreadyResumed else { return }
                body()
            }

            // Independent queue: must NOT be `queue`, since `queue` may be synchronously
            // blocked inside the AppleScript call this is meant to time out.
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + outerDeadline) {
                finish {
                    continuation.resume(throwing: ScriptError(code: -1712, message: "AppleEvent bridge safety timeout"))
                }
            }

            queue.async {
                guard let script = NSAppleScript(source: wrapped) else {
                    finish {
                        continuation.resume(throwing: ScriptError(code: -1, message: "Failed to construct AppleScript"))
                    }
                    return
                }
                var errorInfo: NSDictionary?
                let result = script.executeAndReturnError(&errorInfo)
                finish {
                    if let errorInfo {
                        let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? -1
                        let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error"
                        continuation.resume(throwing: ScriptError(code: code, message: message))
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }
}
