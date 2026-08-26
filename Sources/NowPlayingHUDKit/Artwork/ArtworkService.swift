import AppKit
import Foundation

/// Resolves an `ArtworkSource` into a displayable `NSImage`, backed by `ArtworkCache`.
///
/// Concurrent requests for the *same* artwork (e.g. the HUD and the menu bar popover both asking
/// for the currently-playing track's art at once) are coalesced into a single fetch via
/// `inFlight` — actor method calls are reentrant at `await` points, so without this, two
/// simultaneous callers would each kick off their own duplicate download.
///
/// On a rapid skip, each new track has a *different* cache key, so a stale fetch for the
/// previous track is never awaited by anything anymore — new calls proceed immediately (actor
/// reentrancy lets them interleave rather than queue behind the old one), and the caller simply
/// never applies a result that arrives after it has moved on to a newer track. The old download,
/// if still in flight, is left to finish quietly in the background and only warms the cache; it
/// is not forcibly aborted, since these are small (tens to a few hundred KB) requests and doing
/// so would need per-request cancellation plumbing disproportionate to the benefit.
public actor ArtworkService {
    private let cache: ArtworkCache
    private let session: URLSession
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    public init(cache: ArtworkCache = ArtworkCache(), session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    /// Resolves artwork for `source`. `fetchAppleMusicData` is injected (rather than this module
    /// depending on `AppleMusicPlaybackProvider` directly) so Artwork stays decoupled from
    /// Playback; the App layer wires it to `PlaybackCoordinator.fetchAppleMusicArtwork(trackID:)`.
    public func image(
        for source: ArtworkSource,
        fetchAppleMusicData: @Sendable @escaping (String) async -> Data?
    ) async -> NSImage? {
        switch source {
        case .none:
            return nil
        case .remote(let url):
            let key = ArtworkCacheKey.forRemoteURL(url)
            let session = self.session
            return await resolve(key: key) {
                guard let (data, response) = try? await session.data(from: url),
                      let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    return nil
                }
                return data
            }
        case .appleEventBytes(let cacheKey):
            return await resolve(key: cacheKey) {
                await fetchAppleMusicData(cacheKey)
            }
        }
    }

    private func resolve(key: String, fetch: @Sendable @escaping () async -> Data?) async -> NSImage? {
        if let cached = await cache.image(forKey: key) {
            return cached
        }
        if let existing = inFlight[key] {
            return await existing.value
        }

        let cache = self.cache
        let task = Task<NSImage?, Never> {
            guard let data = await fetch() else { return nil }
            return await cache.store(data: data, forKey: key)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }
}
