import SwiftUI

/// A thin, subtle progress indicator. Position is *extrapolated* locally from the last known
/// `ProgressEstimator` via `TimelineView` — this is the only thing in the whole app that
/// "ticks," and SwiftUI only invokes its content closure while this view is actually on screen,
/// so it costs nothing the moment the HUD is hidden or the window isn't visible. There is no
/// separate polling timer anywhere.
struct ProgressBarView: View {
    var estimator: ProgressEstimator
    var height: CGFloat = 3
    var tint: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { _ in
            GeometryReader { proxy in
                let fraction = estimator.fractionComplete(at: .now)
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Elapsed / remaining time labels, extrapolated the same way as `ProgressBarView`.
struct TimeLabelsView: View {
    var estimator: ProgressEstimator

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            HStack {
                Text(TimeFormatter.string(from: estimator.position(at: .now)))
                Spacer()
                Text("-" + TimeFormatter.string(from: max(0, estimator.duration - estimator.position(at: .now))))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}

/// Just the "-M:SS" remaining-time label, for the compact (non-expanded) HUD — a single small
/// number rather than `TimeLabelsView`'s full elapsed/remaining pair, which is reserved for the
/// wider expanded layout next to the scrubber.
struct RemainingTimeLabel: View {
    var estimator: ProgressEstimator

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            Text("-" + TimeFormatter.string(from: max(0, estimator.duration - estimator.position(at: .now))))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

enum TimeFormatter {
    static func string(from seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}
