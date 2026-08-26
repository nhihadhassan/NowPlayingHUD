import AppKit
import SwiftUI

/// A single-shortcut recorder control: click to record, press a combo (must include at least
/// one modifier — enforced by `KeyCombo.init?(keyCode:cocoaModifiers:)`), click the "x" to clear.
/// Uses a local `NSEvent` monitor scoped to the moment recording is active, not a global one —
/// this only needs to see key events directed at this app's own Settings window.
public struct ShortcutRecorderView: View {
    @Binding var combo: KeyCombo?
    var onValidate: (KeyCombo) -> Bool

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var conflictMessage: String?

    public init(combo: Binding<KeyCombo?>, onValidate: @escaping (KeyCombo) -> Bool = { _ in true }) {
        self._combo = combo
        self.onValidate = onValidate
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                Button(action: toggleRecording) {
                    Text(isRecording ? "Press shortcut…" : (combo?.displayString ?? "Record Shortcut"))
                        .frame(minWidth: 120)
                        .font(.system(size: 12, weight: combo == nil ? .regular : .medium, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .accentColor : nil)

                if combo != nil {
                    Button {
                        combo = nil
                        conflictMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear shortcut")
                }
            }
            if let conflictMessage {
                Text(conflictMessage).font(.caption2).foregroundStyle(.red)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        conflictMessage = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            defer { stopRecording() }
            guard event.keyCode != 53 else { return nil } // Escape cancels without setting anything
            guard let candidate = KeyCombo(keyCode: UInt32(event.keyCode), cocoaModifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)) else {
                conflictMessage = "Include at least one modifier key."
                return nil
            }
            guard onValidate(candidate) else {
                conflictMessage = "That combination is already in use."
                return nil
            }
            combo = candidate
            return nil // swallow the event — it was consumed as a shortcut recording, not typed input
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
