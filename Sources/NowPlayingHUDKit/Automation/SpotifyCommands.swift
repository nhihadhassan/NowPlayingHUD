import Foundation

/// Builds and parses the small set of AppleScript snippets `SpotifyPlaybackProvider` needs,
/// keeping every string of AppleScript source (and every fragile four-char-code / list-index
/// assumption) in one reviewable place.
///
/// Facts this file depends on, verified against a live Spotify client (v1.2.97.270) rather than
/// assumed from the sdef alone:
/// - `duration of <track>` is **milliseconds** (the sdef's "in seconds" description is wrong).
/// - `player position` is seconds, as a `real`.
/// - `player state as string` coerces to the lowercase enumerator name ("playing"/"paused"/
///   "stopped"), matching the sdef's `<enumerator name>` values.
/// - `spotify url of <track>` returns the **URI form** `spotify:track:<id>`, not a web link —
///   `https://open.spotify.com/track/<id>` is constructed locally for "Copy Track Link".
/// - There is no `seek` command; seeking is done by setting `player position`.
/// - `shuffling enabled`/`repeating enabled` share the four-char code `pReE` in Spotify's own
///   sdef, so this bridge never reads them — only the unambiguous `shuffling`/`repeating`.
enum SpotifyScript {
    /// One batched round trip for the entire playback state, returned as a 13-element list so a
    /// single Apple Event captures everything instead of one event per property.
    static let snapshot = """
    tell application "Spotify"
        set _state to (player state as string)
        set _pos to player position
        set _vol to sound volume
        set _shuf to shuffling
        set _rep to repeating
        if _state is not "stopped" then
            set _t to current track
            set _name to name of _t
            set _artist to artist of _t
            set _album to album of _t
            set _albumArtist to album artist of _t
            set _dur to duration of _t
            set _id to id of _t
            set _art to artwork url of _t
        else
            set _name to ""
            set _artist to ""
            set _album to ""
            set _albumArtist to ""
            set _dur to 0
            set _id to ""
            set _art to ""
        end if
    end tell
    return {_state, _pos, _vol, _shuf, _rep, _name, _artist, _album, _albumArtist, _dur, _id, _art}
    """

    static func parseSnapshot(_ descriptor: NSAppleEventDescriptor) -> PlaybackSnapshot {
        // AppleScript is 1-indexed.
        func item(_ index: Int) -> NSAppleEventDescriptor? { descriptor.atIndex(index) }

        let stateString = item(1)?.stringValue ?? "stopped"
        let position = item(2)?.doubleValue ?? 0
        let volume = Int(item(3)?.int32Value ?? 0)
        let shuffle = (item(4)?.booleanValue) ?? false
        let repeating = (item(5)?.booleanValue) ?? false
        let name = item(6)?.stringValue ?? ""
        let artist = item(7)?.stringValue ?? ""
        let album = item(8)?.stringValue ?? ""
        let albumArtist = item(9)?.stringValue
        let durationMillis = item(10)?.int32Value ?? 0
        let trackID = item(11)?.stringValue ?? ""
        let artworkURLString = item(12)?.stringValue ?? ""

        let state: PlaybackState = {
            switch stateString {
            case "playing": return .playing
            case "paused": return .paused
            default: return .stopped
            }
        }()

        var track: Track?
        if !trackID.isEmpty {
            let artwork: ArtworkSource = {
                guard let url = URL(string: artworkURLString), !artworkURLString.isEmpty else { return .none }
                return .remote(url)
            }()
            track = Track(
                id: trackID,
                provider: .spotify,
                title: name,
                artist: artist,
                album: album,
                albumArtist: albumArtist?.isEmpty == true ? nil : albumArtist,
                duration: .milliseconds(Int64(durationMillis)),
                artwork: artwork,
                externalURL: URL(string: trackID) // "spotify:track:..." is itself a valid URI.
            )
        }

        return PlaybackSnapshot(
            track: track,
            state: state,
            reportedPosition: position,
            capturedAt: .now,
            volume: volume,
            shuffle: shuffle,
            repeatMode: repeating ? .all : .off,
            capabilities: .spotify
        )
    }

    static func setVolume(_ value: Int) -> String {
        "tell application \"Spotify\" to set sound volume to \(value.clamped(0...100))"
    }

    static func setShuffle(_ value: Bool) -> String {
        "tell application \"Spotify\" to set shuffling to \(value)"
    }

    /// Spotify's `repeating` is a plain boolean — `.one` is not representable and is mapped to
    /// `.all` by `RepeatMode.next(supporting:)` before it ever reaches here.
    static func setRepeat(_ value: Bool) -> String {
        "tell application \"Spotify\" to set repeating to \(value)"
    }

    static func seek(to seconds: TimeInterval) -> String {
        "tell application \"Spotify\" to set player position to \(seconds)"
    }

    static let play = "tell application \"Spotify\" to play"
    static let pause = "tell application \"Spotify\" to pause"
    static let playPause = "tell application \"Spotify\" to playpause"
    static let next = "tell application \"Spotify\" to next track"
    static let previous = "tell application \"Spotify\" to previous track"

    /// The public, shareable web link for a track, built locally from its URI since
    /// `spotify url` returns the URI form rather than a web link (verified empirically).
    static func shareableLink(forTrackID id: String) -> URL? {
        guard let range = id.range(of: "spotify:track:") else { return nil }
        let bareID = id[range.upperBound...]
        return URL(string: "https://open.spotify.com/track/\(bareID)")
    }
}

