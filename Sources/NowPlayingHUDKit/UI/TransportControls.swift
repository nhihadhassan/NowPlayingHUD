import SwiftUI

/// Previous / play-pause / next. Shared by the HUD's expanded state and the menu bar mini player.
struct TransportControls: View {
    var isPlaying: Bool
    var size: CGFloat = 15
    var onPrevious: () -> Void
    var onPlayPause: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            TransportButton(systemName: "backward.end.fill", size: size * 0.8, action: onPrevious)
                .accessibilityLabel("Previous")
            TransportButton(systemName: isPlaying ? "pause.fill" : "play.fill", size: size, action: onPlayPause)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .keyboardShortcut(.space, modifiers: [])
            TransportButton(systemName: "forward.end.fill", size: size * 0.8, action: onNext)
                .accessibilityLabel("Next")
        }
    }
}

/// A single transport button with tactile press feedback (a brief scale-down), matching the
/// "buttons should feel tactile" quality-of-life note without needing a custom ButtonStyle per
/// call site.
struct TransportButton: View {
    var systemName: String
    var size: CGFloat
    var action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size * 2.2, height: size * 2.2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.85 : 1)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Volume slider + shuffle/repeat toggles, shown in the HUD's expanded state and the mini player.
struct SecondaryControlsRow: View {
    var volume: Int
    var shuffle: Bool
    var repeatMode: RepeatMode
    var capabilities: PlayerCapabilities
    var onVolumeChange: (Int) -> Void
    var onToggleShuffle: () -> Void
    var onCycleRepeat: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if capabilities.contains(.shuffle) {
                ToggleGlyphButton(systemName: "shuffle", isActive: shuffle, action: onToggleShuffle)
                    .accessibilityLabel("Shuffle")
                    .accessibilityValue(shuffle ? "On" : "Off")
            }
            if capabilities.contains(.volume) {
                HStack(spacing: 6) {
                    Image(systemName: volumeSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Slider(
                        value: Binding(
                            get: { Double(volume) },
                            set: { onVolumeChange(Int($0.rounded())) }
                        ),
                        in: 0...100
                    )
                    .controlSize(.mini)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Volume")
                .accessibilityValue("\(volume) percent")
            }
            if capabilities.contains(.repeatAll) || capabilities.contains(.repeatOne) {
                ToggleGlyphButton(systemName: repeatMode.symbolName, isActive: repeatMode.isActive, action: onCycleRepeat)
                    .accessibilityLabel("Repeat")
                    .accessibilityValue(repeatMode.rawValue.capitalized)
            }
        }
    }

    private var volumeSymbol: String {
        switch volume {
        case 0: return "speaker.slash.fill"
        case 1..<34: return "speaker.wave.1.fill"
        case 34..<67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

struct ToggleGlyphButton: View {
    var systemName: String
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
