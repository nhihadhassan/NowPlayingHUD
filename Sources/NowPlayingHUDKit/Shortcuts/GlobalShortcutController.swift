import Carbon
import Foundation

/// Global keyboard shortcuts via Carbon's `RegisterEventHotKey`/`InstallEventHandler`.
///
/// Deliberately not the Accessibility-permission-requiring `CGEvent` tap approach, and not a
/// third-party dependency: `RegisterEventHotKey` is the same public, no-extra-permission
/// mechanism macOS itself has used for global shortcuts since Mac OS X, and is sufficient for
/// simple "fire an action on this exact combo" bindings — there is no need for anything heavier
/// here (no shortcut is bound by default; the user opts in per-action in Settings → Shortcuts).
public final class GlobalShortcutController: @unchecked Sendable {
    public typealias ActionHandler = (ShortcutAction) -> Void

    private var actionHandler: ActionHandler?
    private var eventHandlerRef: EventHandlerRef?
    private var registrations: [ShortcutAction: (ref: EventHotKeyRef, id: UInt32)] = [:]
    private var idToAction: [UInt32: ShortcutAction] = [:]
    private var nextHotKeyID: UInt32 = 1

    /// A stable 4-byte signature identifying this app's hotkeys to the system, distinct from
    /// other apps' registrations sharing the same event dispatcher target.
    private let signature = OSType(fourCharCode("NwPH"))

    public init() {}

    deinit { stop() }

    /// Installs the single shared Carbon event handler. Idempotent; safe to call once at app
    /// launch before any shortcuts are actually bound.
    public func start(handler: @escaping ActionHandler) {
        actionHandler = handler
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetEventDispatcherTarget(), { _, eventRef, userData in
            guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            Unmanaged<GlobalShortcutController>.fromOpaque(userData).takeUnretainedValue().fire(id: hotKeyID.id)
            return noErr
        }, 1, &eventType, selfPointer, &eventHandlerRef)
    }

    /// Stops delivering shortcut events and unregisters every bound combo. Safe to call multiple
    /// times and during app teardown.
    public func stop() {
        for (_, registration) in registrations { UnregisterEventHotKey(registration.ref) }
        registrations.removeAll()
        idToAction.removeAll()
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        eventHandlerRef = nil
    }

    /// Binds `combo` to `action`, replacing any existing binding for that action. Passing `nil`
    /// simply unbinds it. Returns `false` if the combo is already claimed by *another*
    /// application (or is otherwise unregisterable) so Settings can tell the user, rather than
    /// silently failing.
    @discardableResult
    public func setCombo(_ combo: KeyCombo?, for action: ShortcutAction) -> Bool {
        if let existing = registrations[action] {
            UnregisterEventHotKey(existing.ref)
            registrations[action] = nil
            idToAction[existing.id] = nil
        }
        guard let combo else { return true }

        let id = nextHotKeyID
        nextHotKeyID += 1
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        registrations[action] = (ref, id)
        idToAction[id] = action
        return true
    }

    private func fire(id: UInt32) {
        guard let action = idToAction[id] else { return }
        actionHandler?(action)
    }
}
