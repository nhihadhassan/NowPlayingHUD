import Foundation

/// Builds and parses the AppleScript this app sends to Apple Music (`Music.app`), read directly
/// from the live `com.apple.Music.sdef` shipped on this Mac.
///
/// Facts this file depends on, taken from that dictionary (not the notification, which — unlike
/// Spotify's — was not empirically re-verified; see the note on `notificationIsTriggerOnly`):
/// - `duration` on a `track` is **real seconds** (unlike Spotify's milliseconds).
/// - `persistent ID` is a stable hex-string identifier, unaffected by library changes — used as
///   both the track ID and the artwork cache key.
/// - `song repeat` is a genuine tri-state enumeration (`off`/`one`/`all`), coercible `as string`
///   to those exact lowercase names — Apple Music gets the repeat-one control Spotify cannot.
/// - `back track` (not `previous track`) is the command that reproduces the familiar "restart if
///   already playing, else go to the previous track" UX — Apple's own scripting dictionary
///   documents this explicitly, so no bespoke position-threshold logic is needed here the way it
///   is for Spotify.
/// - Artwork is exposed as raw image bytes (`data of artwork 1 of track`), not a URL.
enum MusicScript {
    /// `com.apple.Music.playerInfo`'s `userInfo` keys are well-documented across the broader
    /// AppleScript/menu-bar-app community but were not independently re-verified against a live,
    /// playing instance in this environment (doing so would require starting audio playback —
    /// e.g. an Apple Music subscription stream — as a side effect of a build, which this project
    /// avoids). Rather than ship guessed key names as load-bearing logic, this provider treats
    /// the notification purely as a **trigger** and always re-derives the full snapshot from the
    /// sdef-verified Apple Event script below. This is still fully event-driven (no polling); it
    /// simply skips the notification-payload fast path Spotify's verified keys make possible.
    static let notificationIsTriggerOnly = true

    static let snapshot = """
    tell application "Music"
        set _state to (player state as string)
        set _pos to player position
        set _vol to sound volume
        set _shuf to shuffle enabled
        set _rep to (song repeat as string)
        if _state is not "stopped" then
            try
                set _t to current track
                set _name to name of _t
                set _artist to artist of _t
                set _album to album of _t
                set _albumArtist to album artist of _t
                set _dur to duration of _t
                set _id to persistent ID of _t
            on error
                set _name to ""
                set _artist to ""
                set _album to ""
                set _albumArtist to ""
                set _dur to 0
                set _id to ""
            end try
        else
            set _name to ""
            set _artist to ""
            set _album to ""
            set _albumArtist to ""
            set _dur to 0
            set _id to ""
        end if
    end tell
    return {_state, _pos, _vol, _shuf, _rep, _name, _artist, _album, _albumArtist, _dur, _id}
    """

    static func parseSnapshot(_ descriptor: NSAppleEventDescriptor) -> PlaybackSnapshot {
        func item(_ index: Int) -> NSAppleEventDescriptor? { descriptor.atIndex(index) }

        let stateString = item(1)?.stringValue ?? "stopped"
        let position = item(2)?.doubleValue ?? 0
        let volume = Int(item(3)?.int32Value ?? 0)
        let shuffle = item(4)?.booleanValue ?? false
        let repeatString = item(5)?.stringValue ?? "off"
        let name = item(6)?.stringValue ?? ""
        let artist = item(7)?.stringValue ?? ""
        let album = item(8)?.stringValue ?? ""
        let albumArtist = item(9)?.stringValue
        let durationSeconds = item(10)?.doubleValue ?? 0
        let persistentID = item(11)?.stringValue ?? ""

        let state: PlaybackState
        switch stateString {
        case "playing", "fast forwarding", "rewinding": state = .playing
        case "paused": state = .paused
        default: state = .stopped
        }

        let repeatMode: RepeatMode
        switch repeatString {
        case "one": repeatMode = .one
        case "all": repeatMode = .all
        default: repeatMode = .off
        }

        var track: Track?
        if !persistentID.isEmpty {
            track = Track(
                id: persistentID,
                provider: .appleMusic,
                title: name,
                artist: artist,
                album: album,
                albumArtist: albumArtist?.isEmpty == true ? nil : albumArtist,
                duration: .seconds(durationSeconds),
                artwork: .appleEventBytes(cacheKey: persistentID),
                externalURL: nil
            )
        }

        return PlaybackSnapshot(
            track: track,
            state: state,
            reportedPosition: position,
            capturedAt: .now,
            volume: volume,
            shuffle: shuffle,
            repeatMode: repeatMode,
            capabilities: .appleMusic
        )
    }

    /// Fetches raw artwork bytes for the track whose `persistent ID` matches `trackID`, guarding
    /// against the track having already changed by the time this (slower, artwork-specific)
    /// round trip completes.
    static func fetchArtwork(trackID: String) -> String {
        """
        tell application "Music"
            if (current track exists) and (persistent ID of current track is "\(trackID)") and ((count of artworks of current track) > 0) then
                return data of artwork 1 of current track
            else
                return missing value
            end if
        end tell
        """
    }

    static func setVolume(_ value: Int) -> String {
        "tell application \"Music\" to set sound volume to \(value.clamped(0...100))"
    }

    static func setShuffle(_ value: Bool) -> String {
        "tell application \"Music\" to set shuffle enabled to \(value)"
    }

    static func setRepeat(_ mode: RepeatMode) -> String {
        "tell application \"Music\" to set song repeat to \(mode.rawValue)"
    }

    static func seek(to seconds: TimeInterval) -> String {
        "tell application \"Music\" to set player position to \(seconds)"
    }

    static let play = "tell application \"Music\" to play"
    static let pause = "tell application \"Music\" to pause"
    static let playPause = "tell application \"Music\" to playpause"
    static let next = "tell application \"Music\" to next track"
    /// See the type-level doc comment: `back track` (not `previous track`) is Apple's own
    /// "restart-or-go-back" command.
    static let previous = "tell application \"Music\" to back track"
}
