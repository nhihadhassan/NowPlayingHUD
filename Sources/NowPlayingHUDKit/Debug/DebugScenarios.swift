import Foundation

/// Canned playback scenarios for exercising the HUD without touching a real player — driven
/// through the menu bar's "Debug" submenu, which only appears when developer mode is on (see
/// `PreferencesStore.developerModeEnabled`). Never shown in the normal production UI.
public enum DebugScenarios {
    public static func normalTrack() -> PlaybackSnapshot {
        snapshot(title: "As It Was", artist: "Harry Styles", album: "Harry's House", duration: 167)
    }

    public static func veryLongTitles() -> PlaybackSnapshot {
        snapshot(
            title: "A Genuinely Absurdly Long Track Title That Should Truncate Gracefully Without Breaking The Layout",
            artist: "An Artist Name That Is Also Considerably Longer Than Usual",
            album: "An Equally Long Album Name For Good Measure",
            duration: 240
        )
    }

    public static func missingArtwork() -> PlaybackSnapshot {
        snapshot(title: "Track With No Artwork", artist: "Unknown Artist", album: "", duration: 200, artwork: .none)
    }

    /// Five rapid, distinct tracks — used to visually confirm exactly one HUD updates in place
    /// five times rather than stacking multiple panels.
    public static func rapidSkipSequence() -> [PlaybackSnapshot] {
        (1...5).map { i in
            snapshot(title: "Rapid Skip Track \(i)", artist: "Skip Test Artist", album: "Skip Test Album", duration: 180)
        }
    }

    /// Distinct dominant colors, to visually confirm the artwork-derived accent tint adapts
    /// per track and stays legible against both light and dark HUD materials.
    public static func variedColors() -> [PlaybackSnapshot] {
        [
            snapshot(title: "Warm Red Artwork", artist: "Color Test", album: "", duration: 200, artwork: .none),
            snapshot(title: "Cool Blue Artwork", artist: "Color Test", album: "", duration: 200, artwork: .none),
            snapshot(title: "Deep Green Artwork", artist: "Color Test", album: "", duration: 200, artwork: .none)
        ]
    }

    private static func snapshot(
        title: String, artist: String, album: String, duration: TimeInterval, artwork: ArtworkSource = .none
    ) -> PlaybackSnapshot {
        let track = Track(
            id: UUID().uuidString, provider: .spotify, title: title, artist: artist, album: album,
            duration: .seconds(duration), artwork: artwork,
            externalURL: URL(string: "https://open.spotify.com/")
        )
        return PlaybackSnapshot(
            track: track, state: .playing, reportedPosition: 12, capturedAt: .now,
            volume: 65, shuffle: false, repeatMode: .off, capabilities: .spotify
        )
    }
}
