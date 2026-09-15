import SwiftUI

/// A draggable progress scrubber. Seeking is committed only when the drag ends — not on every
/// pixel of movement — so dragging never floods the Apple Event bridge with `set player
/// position` calls; the local `dragFraction` gives instant visual feedback during the drag
/// itself, independent of the live `TimelineView`-driven position underneath it.
struct ScrubberView: View {
    var estimator: ProgressEstimator
    var tint: Color
    var isEnabled: Bool
    var onSeek: (TimeInterval) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: isEnabled ? 1.0 / 20.0 : 3600)) { _ in
            CapsuleSlider(
                fraction: estimator.fractionComplete(at: .now), tint: tint, isEnabled: isEnabled,
                onCommit: { onSeek($0 * estimator.duration) }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(TimeFormatter.string(from: estimator.position(at: .now)))
        .accessibilityAdjustableAction { direction in
            let step: TimeInterval = 5
            switch direction {
            case .increment: onSeek(min(estimator.duration, estimator.position(at: .now) + step))
            case .decrement: onSeek(max(0, estimator.position(at: .now) - step))
            @unknown default: break
            }
        }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
