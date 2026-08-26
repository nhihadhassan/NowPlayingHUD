import Foundation
import NowPlayingHUDKit

private func track(_ id: String) -> Track {
    Track(id: id, provider: .spotify, title: "T", artist: "A", album: "Al", duration: .seconds(200))
}

private func snapshot(trackID: String?, state: PlaybackState) -> PlaybackSnapshot {
    PlaybackSnapshot(
        track: trackID.map(track), state: state, reportedPosition: 0, capturedAt: .now,
        volume: 50, shuffle: false, repeatMode: .off, capabilities: .spotify
    )
}

func registerHUDPresentationPolicyTests(on runner: TestRunner) {
    runner.suite("HUDPresentationPolicy.classify") {
        runner.test("nil previous is always a track change") {
            try expect(HUDPresentationPolicy.classify(previous: nil, new: snapshot(trackID: "a", state: .playing)) == .trackChanged)
        }
        runner.test("different track id is a track change even if state also differs") {
            let kind = HUDPresentationPolicy.classify(
                previous: snapshot(trackID: "a", state: .paused), new: snapshot(trackID: "b", state: .playing)
            )
            try expect(kind == .trackChanged)
        }
        runner.test("same track, paused to playing, is playResumed") {
            let kind = HUDPresentationPolicy.classify(
                previous: snapshot(trackID: "a", state: .paused), new: snapshot(trackID: "a", state: .playing)
            )
            try expect(kind == .playResumed)
        }
        runner.test("same track, playing to paused, is paused") {
            let kind = HUDPresentationPolicy.classify(
                previous: snapshot(trackID: "a", state: .playing), new: snapshot(trackID: "a", state: .paused)
            )
            try expect(kind == .paused)
        }
        runner.test("same track, same state, is other") {
            let kind = HUDPresentationPolicy.classify(
                previous: snapshot(trackID: "a", state: .playing), new: snapshot(trackID: "a", state: .playing)
            )
            try expect(kind == .other)
        }
    }

    runner.suite("HUDPresentationPolicy.shouldPresent") {
        runner.test("non-significant changes never present, regardless of other settings") {
            let result = HUDPresentationPolicy.shouldPresent(
                isSignificant: false, changeKind: .trackChanged, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: true, showOnPlayResume: true, showOnPause: true, showOnManualControl: true,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: false
            )
            try expect(!result)
        }
        runner.test("automaticHUDEnabled = false suppresses everything") {
            let result = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .trackChanged, automaticHUDEnabled: false, temporarilyDisabled: false,
                showOnTrackChange: true, showOnPlayResume: true, showOnPause: true, showOnManualControl: true,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: false
            )
            try expect(!result)
        }
        runner.test("temporarily disabled suppresses everything") {
            let result = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .trackChanged, automaticHUDEnabled: true, temporarilyDisabled: true,
                showOnTrackChange: true, showOnPlayResume: true, showOnPause: true, showOnManualControl: true,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: false
            )
            try expect(!result)
        }
        runner.test("track change respects showOnTrackChange") {
            let shown = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .trackChanged, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: true, showOnPlayResume: false, showOnPause: false, showOnManualControl: false,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: true
            )
            let hidden = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .trackChanged, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: false, showOnPlayResume: true, showOnPause: true, showOnManualControl: true,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: false
            )
            try expect(shown)
            try expect(!hidden)
        }
        runner.test("hideWhenPlayerFrontmost suppresses a track change while the player is frontmost") {
            let result = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .trackChanged, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: true, showOnPlayResume: true, showOnPause: true, showOnManualControl: true,
                isPlayerFrontmost: true, hideWhenPlayerFrontmost: true
            )
            try expect(!result)
        }
        runner.test("manual control ignores hideWhenPlayerFrontmost — confirmation always wins") {
            let result = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .manualControl, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: false, showOnPlayResume: false, showOnPause: false, showOnManualControl: true,
                isPlayerFrontmost: true, hideWhenPlayerFrontmost: true
            )
            try expect(result)
        }
        runner.test("manual control still respects its own showOnManualControl toggle") {
            let result = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .manualControl, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: true, showOnPlayResume: true, showOnPause: true, showOnManualControl: false,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: false
            )
            try expect(!result)
        }
        runner.test("playResumed and paused each respect their own toggle independently") {
            let resumeShown = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .playResumed, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: false, showOnPlayResume: true, showOnPause: false, showOnManualControl: false,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: false
            )
            let pauseHidden = HUDPresentationPolicy.shouldPresent(
                isSignificant: true, changeKind: .paused, automaticHUDEnabled: true, temporarilyDisabled: false,
                showOnTrackChange: false, showOnPlayResume: true, showOnPause: false, showOnManualControl: false,
                isPlayerFrontmost: false, hideWhenPlayerFrontmost: false
            )
            try expect(resumeShown)
            try expect(!pauseHidden)
        }
    }
}
