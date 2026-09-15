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
    var tint: Color = .accentColor
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
                HStack(spacing: 8) {
                    Image(systemName: volumeSymbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 13)
                        .contentTransition(.symbolEffect(.replace))
                    CapsuleSlider(
                        fraction: Double(volume) / 100, tint: tint, isEnabled: true,
                        onCommit: { onVolumeChange(Int(($0 * 100).rounded())) }
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Volume")
                .accessibilityValue("\(volume) percent")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: onVolumeChange(min(100, volume + 5))
                    case .decrement: onVolumeChange(max(0, volume - 5))
                    @unknown default: break
                    }
                }
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

/// The capsule-track-plus-circular-handle visual shared by the progress scrubber and the volume
/// control, so both read as one design language rather than a custom scrubber next to a stock
/// `Slider`. Commits its value only when the drag ends — the same discipline `ScrubberView`
/// already used for seeking, now applied to volume too, so dragging the volume slider can't flood
/// the Apple Event bridge with a `set sound volume` call per pixel of movement.
struct CapsuleSlider: View {
    var fraction: Double
    var tint: Color
    var isEnabled: Bool
    var trackHeight: CGFloat = 4
    var handleDiameter: CGFloat = 10
    var onCommit: (Double) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let shown = (dragFraction ?? fraction).clamped(to: 0...1)

            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary).frame(height: trackHeight)
                Capsule().fill(tint).frame(width: max(0, width * shown), height: trackHeight)
                Circle()
                    .fill(tint)
                    .frame(width: handleDiameter, height: handleDiameter)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                    .offset(x: max(0, min(width, width * shown)) - handleDiameter / 2)
                    .opacity(isEnabled ? 1 : 0)
                    .scaleEffect(dragFraction != nil ? 1.15 : 1)
                    .animation(.easeOut(duration: 0.12), value: dragFraction != nil)
            }
            .frame(height: max(trackHeight, handleDiameter))
            .contentShape(Rectangle())
            .gesture(
                isEnabled ?
                DragGesture(minimumDistance: 0)
                    .onChanged { value in dragFraction = (value.location.x / width).clamped(to: 0...1) }
                    .onEnded { value in
                        let final = (value.location.x / width).clamped(to: 0...1)
                        onCommit(final)
                        dragFraction = nil
                    }
                : nil
            )
        }
        .frame(height: max(trackHeight, handleDiameter))
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
