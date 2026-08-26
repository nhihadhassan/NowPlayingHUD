import Foundation
import NowPlayingHUDKit

private func track(_ id: String) -> Track {
    Track(id: id, provider: .spotify, title: "T", artist: "A", album: "Al", duration: .seconds(200))
}

private func snapshot(
    trackID: String?, state: PlaybackState, position: TimeInterval, at instant: ContinuousClock.Instant
) -> PlaybackSnapshot {
    PlaybackSnapshot(
        track: trackID.map(track), state: state, reportedPosition: position, capturedAt: instant,
        volume: 50, shuffle: false, repeatMode: .off, capabilities: .spotify
    )
}

func registerPlaybackSnapshotDedupTests(on runner: TestRunner) {
    runner.suite("PlaybackSnapshot dedup") {
        runner.test("first snapshot is always significant") {
            let now = ContinuousClock.now
            let s = snapshot(trackID: "a", state: .playing, position: 0, at: now)
            try expect(s.isSignificantChange(from: nil))
        }

        runner.test("identical track and state is not significant") {
            let t0 = ContinuousClock.now
            let first = snapshot(trackID: "a", state: .playing, position: 0, at: t0)
            // Reported 2s later, having advanced ~2s of real elapsed time — exactly what
            // Spotify's duplicate `PlaybackStateChanged` notification looks like.
            let t1 = t0.advanced(by: .seconds(2))
            let second = snapshot(trackID: "a", state: .playing, position: 2, at: t1)
            try expect(!second.isSignificantChange(from: first))
        }

        runner.test("track change is significant") {
            let now = ContinuousClock.now
            let first = snapshot(trackID: "a", state: .playing, position: 0, at: now)
            let second = snapshot(trackID: "b", state: .playing, position: 0, at: now.advanced(by: .seconds(1)))
            try expect(second.isSignificantChange(from: first))
        }

        runner.test("play/pause transition is significant") {
            let now = ContinuousClock.now
            let first = snapshot(trackID: "a", state: .playing, position: 10, at: now)
            let second = snapshot(trackID: "a", state: .paused, position: 10, at: now.advanced(by: .seconds(1)))
            try expect(second.isSignificantChange(from: first))
        }

        runner.test("explicit seek is significant") {
            let now = ContinuousClock.now
            let first = snapshot(trackID: "a", state: .playing, position: 10, at: now)
            // Only 1 second of wall time passed, but position jumped by 60s — a seek, not drift.
            let second = snapshot(trackID: "a", state: .playing, position: 70, at: now.advanced(by: .seconds(1)))
            try expect(second.isSignificantChange(from: first))
        }

        runner.test("small drift within threshold is not significant") {
            let now = ContinuousClock.now
            let first = snapshot(trackID: "a", state: .playing, position: 10, at: now)
            // 3 seconds of wall time passed, position only advanced 3.4s — within normal slack.
            let second = snapshot(trackID: "a", state: .playing, position: 13.4, at: now.advanced(by: .seconds(3)))
            try expect(!second.isSignificantChange(from: first))
        }

        runner.test("going from no track to a track is significant") {
            let now = ContinuousClock.now
            let first = snapshot(trackID: nil, state: .stopped, position: 0, at: now)
            let second = snapshot(trackID: "a", state: .playing, position: 0, at: now.advanced(by: .seconds(1)))
            try expect(second.isSignificantChange(from: first))
        }

        // The scenario from the spec: skipping through five songs rapidly should still be seen
        // as five *separate* significant events (so exactly one HUD updates in place five
        // times), never collapsed into zero or duplicated by Spotify's habit of firing more than
        // once per change.
        runner.test("rapid skips are each significant exactly once") {
            let now = ContinuousClock.now
            var previous: PlaybackSnapshot?
            var significantCount = 0
            for i in 0..<5 {
                let t = now.advanced(by: .milliseconds(i * 300))
                // Simulate Spotify firing twice per real change: once immediately, once ~50ms
                // later with a duplicate/near-identical payload.
                let primary = snapshot(trackID: "track-\(i)", state: .playing, position: 0, at: t)
                if primary.isSignificantChange(from: previous) { significantCount += 1 }
                previous = primary
                let duplicate = snapshot(trackID: "track-\(i)", state: .playing, position: 0.05, at: t.advanced(by: .milliseconds(50)))
                if duplicate.isSignificantChange(from: previous) { significantCount += 1 }
                previous = duplicate
            }
            try expect(significantCount == 5, "expected 5 significant events, got \(significantCount)")
        }
    }
}
