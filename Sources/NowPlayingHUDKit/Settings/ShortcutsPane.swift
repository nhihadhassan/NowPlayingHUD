import SwiftUI

struct ShortcutsPane: View {
    @Bindable var preferences: PreferencesStore
    var shortcutController: GlobalShortcutController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(
                title: "Shortcuts",
                subtitle: "Global keyboard shortcuts. Nothing is bound by default — choose your own; existing shortcuts elsewhere are never overridden."
            )

            SettingsGroup("Global Shortcuts") {
                ForEach(ShortcutAction.allCases) { action in
                    LabeledContent {
                        ShortcutRecorderView(
                            combo: bindingFor(action),
                            onValidate: { candidate in isAvailable(candidate, for: action) }
                        )
                    } label: {
                        Label(action.displayName, systemImage: action.symbolName)
                    }
                }
            }

            Text("Media keys keep working normally with your player — there's no need for a shortcut to just play/pause via the keyboard's media keys.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func bindingFor(_ action: ShortcutAction) -> Binding<KeyCombo?> {
        Binding(
            get: { preferences.shortcutBindings[action] },
            set: { newValue in
                preferences.shortcutBindings[action] = newValue
                shortcutController.setCombo(newValue, for: action)
            }
        )
    }

    private func isAvailable(_ combo: KeyCombo, for action: ShortcutAction) -> Bool {
        !preferences.shortcutBindings.contains { $0.key != action && $0.value == combo }
    }
}
