import Foundation
import NowPlayingHUDKit

private func closeEnough(_ a: Double, _ b: Double, _ tolerance: Double = 0.001) -> Bool {
    abs(a - b) < tolerance
}

func registerProgressEstimatorTests(on runner: TestRunner) {
    runner.suite("ProgressEstimator") {
        runner.test("playing extrapolates forward") {
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 10, capturedAt: start, state: .playing, duration: 200)
            let later = start.advanced(by: .seconds(5))
            try expect(closeEnough(estimator.position(at: later), 15))
        }

        runner.test("paused never advances") {
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 42, capturedAt: start, state: .paused, duration: 200)
            let later = start.advanced(by: .seconds(30))
            try expect(closeEnough(estimator.position(at: later), 42))
        }

        runner.test("stopped never advances") {
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 0, capturedAt: start, state: .stopped, duration: 200)
            let later = start.advanced(by: .seconds(30))
            try expect(closeEnough(estimator.position(at: later), 0))
        }

        runner.test("clamps to duration") {
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 195, capturedAt: start, state: .playing, duration: 200)
            let later = start.advanced(by: .seconds(30)) // would overshoot past 200 without clamping
            try expect(closeEnough(estimator.position(at: later), 200))
        }

        runner.test("clamps never goes negative") {
            let start = ContinuousClock.now
            // A reported position slightly negative (defensive: shouldn't happen, but must not
            // crash or produce a negative on-screen position).
            let estimator = ProgressEstimator(reportedPosition: -1, capturedAt: start, state: .paused, duration: 200)
            try expect(closeEnough(estimator.position(at: start), 0))
        }

        runner.test("fractionComplete is safe against zero duration") {
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 0, capturedAt: start, state: .playing, duration: 0)
            try expect(estimator.fractionComplete(at: start) == 0)
        }

        runner.test("fractionComplete is proportional") {
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 50, capturedAt: start, state: .playing, duration: 200)
            try expect(closeEnough(estimator.fractionComplete(at: start), 0.25))
        }

        runner.test("isFinished detection") {
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 199, capturedAt: start, state: .playing, duration: 200)
            try expect(!estimator.isFinished(at: start))
            try expect(estimator.isFinished(at: start.advanced(by: .seconds(5))))
        }

        runner.test("does not advance backwards for an earlier instant") {
            // Defensive: a stale/racy call for an instant *before* capturedAt must not produce a
            // nonsensical negative-elapsed result.
            let start = ContinuousClock.now
            let estimator = ProgressEstimator(reportedPosition: 10, capturedAt: start, state: .playing, duration: 200)
            let earlier = start.advanced(by: .seconds(-5))
            try expect(closeEnough(estimator.position(at: earlier), 10))
        }
    }
}
