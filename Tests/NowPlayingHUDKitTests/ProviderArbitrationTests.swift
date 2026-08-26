import Foundation
import NowPlayingHUDKit

private func standing(_ id: PlayerIdentifier, state: PlaybackState?, secondsAgo: Double = 0, now: ContinuousClock.Instant) -> ProviderStanding {
    guard let state else {
        return ProviderStanding(identifier: id, snapshot: nil, lastEventAt: nil)
    }
    let track = Track(id: "t-\(id.rawValue)", provider: id, title: "T", artist: "A", album: "Al", duration: .seconds(200))
    let snapshot = PlaybackSnapshot(
        track: track, state: state, reportedPosition: 0, capturedAt: now,
        volume: 50, shuffle: false, repeatMode: .off, capabilities: []
    )
    return ProviderStanding(identifier: id, snapshot: snapshot, lastEventAt: now.advanced(by: .seconds(-secondsAgo)))
}

func registerProviderArbitrationTests(on runner: TestRunner) {
    runner.suite("Provider arbitration") {
        runner.test("no candidates yields nil") {
            try expect(ProviderArbitration.chooseActiveProvider(previousChoice: nil, candidates: []) == nil)
        }

        runner.test("single playing candidate wins") {
            let now = ContinuousClock.now
            let candidates = [
                standing(.spotify, state: .playing, now: now),
                standing(.appleMusic, state: .paused, now: now)
            ]
            try expect(ProviderArbitration.chooseActiveProvider(previousChoice: nil, candidates: candidates) == .spotify)
        }

        runner.test("both playing prefers most recent event") {
            let now = ContinuousClock.now
            let candidates = [
                standing(.spotify, state: .playing, secondsAgo: 10, now: now),
                standing(.appleMusic, state: .playing, secondsAgo: 1, now: now)
            ]
            try expect(ProviderArbitration.chooseActiveProvider(previousChoice: nil, candidates: candidates) == .appleMusic)
        }

        runner.test("neither playing stays with previous choice") {
            let now = ContinuousClock.now
            let candidates = [
                standing(.spotify, state: .paused, now: now),
                standing(.appleMusic, state: .paused, now: now)
            ]
            try expect(ProviderArbitration.chooseActiveProvider(previousChoice: .appleMusic, candidates: candidates) == .appleMusic)
        }

        runner.test("neither playing, no previous choice, falls back to Spotify") {
            let now = ContinuousClock.now
            let candidates = [
                standing(.spotify, state: .paused, now: now),
                standing(.appleMusic, state: .paused, now: now)
            ]
            try expect(ProviderArbitration.chooseActiveProvider(previousChoice: nil, candidates: candidates) == .spotify)
        }

        runner.test("previous choice no longer a candidate falls back to Spotify") {
            let now = ContinuousClock.now
            // Apple Music quit (no snapshot at all); only Spotify remains, paused.
            let candidates = [
                standing(.spotify, state: .paused, now: now),
                standing(.appleMusic, state: nil, now: now)
            ]
            try expect(ProviderArbitration.chooseActiveProvider(previousChoice: .appleMusic, candidates: candidates) == .spotify)
        }

        runner.test("terminated provider is never chosen") {
            let now = ContinuousClock.now
            let candidates = [standing(.spotify, state: nil, now: now)]
            try expect(ProviderArbitration.chooseActiveProvider(previousChoice: .spotify, candidates: candidates) == nil)
        }
    }
}
