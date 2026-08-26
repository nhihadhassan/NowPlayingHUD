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

    @State private var dragFraction: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackHeight: CGFloat = 4
    private let handleDiameter: CGFloat = 10

    var body: some View {
        TimelineView(.periodic(from: .now, by: isEnabled ? 1.0 / 20.0 : 3600)) { _ in
            GeometryReader { proxy in
                let liveFraction = estimator.fractionComplete(at: .now)
                let fraction = dragFraction ?? liveFraction
                let width = proxy.size.width

                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: trackHeight)
                    Capsule().fill(tint).frame(width: max(0, width * fraction), height: trackHeight)
                    Circle()
                        .fill(tint)
                        .frame(width: handleDiameter, height: handleDiameter)
                        .shadow(radius: 1, y: 0.5)
                        .offset(x: max(0, min(width, width * fraction)) - handleDiameter / 2)
                        .opacity(isEnabled ? 1 : 0)
                }
                .frame(height: max(trackHeight, handleDiameter))
                .contentShape(Rectangle())
                .gesture(
                    isEnabled ?
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = (value.location.x / width).clamped(to: 0...1)
                        }
                        .onEnded { value in
                            let finalFraction = (value.location.x / width).clamped(to: 0...1)
                            onSeek(finalFraction * estimator.duration)
                            dragFraction = nil
                        }
                    : nil
                )
            }
        }
        .frame(height: max(trackHeight, handleDiameter))
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
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
