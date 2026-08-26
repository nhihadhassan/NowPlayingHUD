import AppKit
import CryptoKit
import Foundation

/// Derives a filesystem- and `NSCache`-safe key for a piece of artwork.
public enum ArtworkCacheKey {
    /// Spotify artwork is keyed by a hash of its URL (URLs are already unique per artwork
    /// variant, but contain characters unsafe for a bare filename).
    public static func forRemoteURL(_ url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Apple Music artwork is keyed directly by the track's `persistent ID`, which is already a
    /// stable, filename-safe hex string.
    public static func forAppleMusicTrack(_ persistentID: String) -> String {
        "am-\(persistentID)"
    }
}

/// A two-tier artwork cache: an `NSCache` in memory (bounded by count and byte cost) backed by a
/// small, LRU-evicted disk cache — bounded (~64 MB default), never an unbounded library, and
/// never re-downloading artwork already on disk.
public actor ArtworkCache {
    private let memory: NSCache<NSString, NSImage>
    private let diskDirectory: URL
    private let maxDiskBytes: Int
    private let fileManager: FileManager

    // Filesystem modification-date resolution isn't fine enough to trust under rapid writes
    // (two `store` calls a few milliseconds apart — a realistic rapid-skip scenario — can tie),
    // so recency for eviction purposes is tracked with this in-memory, monotonically-increasing
    // counter instead. Entries from a previous app launch that haven't been touched this session
    // simply sort as "oldest" (sequence 0), which is a reasonable cold-start default.
    private var sequenceCounter: UInt64 = 0
    private var lastTouched: [String: UInt64] = [:]

    // Configuration happens on local values, not `self`, before assignment: an actor's
    // (nonisolated) init can't freely read its own actor-isolated stored properties mid-body,
    // only assign them.
    public init(maxDiskBytes: Int = 64 * 1024 * 1024, appSupportSubdirectory: String = "NowPlayingHUD") {
        let localFileManager = FileManager.default
        let base = localFileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? localFileManager.temporaryDirectory
        let directory = base.appendingPathComponent(appSupportSubdirectory, isDirectory: true)
            .appendingPathComponent("Artwork", isDirectory: true)
        try? localFileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let localMemory = NSCache<NSString, NSImage>()
        localMemory.countLimit = 60
        localMemory.totalCostLimit = 24 * 1024 * 1024 // ~24 MB of decoded images in memory

        self.maxDiskBytes = maxDiskBytes
        self.fileManager = localFileManager
        self.diskDirectory = directory
        self.memory = localMemory
    }

    /// Returns a cached image for `key`, checking memory first, then disk (promoting a disk hit
    /// back into memory), or `nil` on a full miss.
    public func image(forKey key: String) -> NSImage? {
        if let cached = memory.object(forKey: key as NSString) {
            markTouched(key)
            return cached
        }
        let fileURL = diskDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: fileURL), let image = NSImage(data: data) else {
            return nil
        }
        markTouched(key)
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        return image
    }

    /// Stores freshly-downloaded artwork under `key`, in both tiers, and runs a cheap eviction
    /// pass to keep the disk tier under budget.
    public func store(data: Data, forKey key: String) -> NSImage? {
        guard let image = NSImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        let fileURL = diskDirectory.appendingPathComponent(key)
        try? data.write(to: fileURL, options: .atomic)
        markTouched(key)
        evictIfNeeded()
        return image
    }

    private func markTouched(_ key: String) {
        sequenceCounter += 1
        lastTouched[key] = sequenceCounter
    }

    /// Deletes least-recently-used files until the disk tier is back under `maxDiskBytes`. Runs
    /// on every store, which is cheap here: artwork changes at most once per track change, never
    /// on a timer, so this directory stays small (a few hundred entries at most).
    private func evictIfNeeded() {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: diskDirectory, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }

        var total = 0
        var withMetadata: [(url: URL, size: Int, sequence: UInt64)] = []
        for url in entries {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize else { continue }
            total += size
            withMetadata.append((url, size, lastTouched[url.lastPathComponent] ?? 0))
        }
        guard total > maxDiskBytes else { return }

        for entry in withMetadata.sorted(by: { $0.sequence < $1.sequence }) {
            guard total > maxDiskBytes else { break }
            try? fileManager.removeItem(at: entry.url)
            lastTouched[entry.url.lastPathComponent] = nil
            total -= entry.size
        }
    }
}
