import SwiftUI

/// The status item's content for every `MenuBarDisplayMode` other than `.iconOnly` (which just
/// uses a plain `NSStatusBarButton.image` — no need for a custom view). Hosted via
/// `NSHostingView` so the "tiny animated playback indicator" mode can use a genuine SF Symbol
/// `symbolEffect`, which isn't available on `NSStatusBarButton` directly.
struct StatusItemContentView: View {
    var mode: MenuBarDisplayMode
    var track: Track?
    var isPlaying: Bool

    var body: some View {
        switch mode {
        case .iconOnly:
            // Unreachable in practice — `MenuBarController` renders `.iconOnly` directly on the
            // button's own `image`/`appearsDisabled`, never through this hosted view. Kept only
            // so the switch stays exhaustive without a `default:` that would silently swallow a
            // real future case.
            EmptyView()
        case .animatedIndicator:
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
        case .trackTitle:
            Text(track?.title ?? "Not Playing")
                .lineLimit(1)
        case .artistDashTrack:
            Text(track.map { "\($0.artist) — \($0.title)" } ?? "Not Playing")
                .lineLimit(1)
        case .compactTwoLine:
            VStack(spacing: 0) {
                Text(track?.title ?? "Not Playing")
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                Text(track?.artist ?? "")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
