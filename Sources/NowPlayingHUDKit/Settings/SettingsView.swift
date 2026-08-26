import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case hud = "HUD"
    case content = "Content"
    case appearance = "Appearance"
    case controls = "Controls"
    case shortcuts = "Shortcuts"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .hud: return "rectangle.inset.filled.badge.record"
        case .content: return "list.bullet.rectangle"
        case .appearance: return "paintbrush"
        case .controls: return "cursorarrow.click"
        case .shortcuts: return "keyboard"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

/// The Settings window's content: a sidebar of sections (`NavigationSplitView`, matching real
/// Mac preference panes rather than a website-in-a-window) plus a live HUD preview that updates
/// instantly as appearance settings change.
public struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    var playback: PlaybackCoordinator
    var hudCoordinator: HUDPresentationCoordinator
    var shortcutController: GlobalShortcutController

    @State private var selection: SettingsSection? = .general

    public init(
        preferences: PreferencesStore, playback: PlaybackCoordinator, hudCoordinator: HUDPresentationCoordinator,
        shortcutController: GlobalShortcutController
    ) {
        self.preferences = preferences
        self.playback = playback
        self.hudCoordinator = hudCoordinator
        self.shortcutController = shortcutController
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbolName).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 170)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    detailContent
                    if (selection ?? .general).showsPreview {
                        Divider()
                        HUDPreviewSection(preferences: preferences)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .general {
        case .general:
            GeneralPane(preferences: preferences, playback: playback)
        case .hud:
            HUDPane(preferences: preferences)
        case .content:
            ContentPane(preferences: preferences)
        case .appearance:
            AppearancePane(preferences: preferences)
        case .controls:
            ControlsPane(preferences: preferences)
        case .shortcuts:
            ShortcutsPane(preferences: preferences, shortcutController: shortcutController)
        case .advanced:
            AdvancedPane(preferences: preferences, playback: playback)
        case .about:
            AboutPane()
        }
    }
}

extension SettingsSection {
    /// The live preview is only relevant while looking at settings that actually change how the
    /// HUD looks — not, say, on the About pane.
    var showsPreview: Bool {
        switch self {
        case .hud, .content, .appearance, .controls: return true
        case .general, .shortcuts, .advanced, .about: return false
        }
    }
}
