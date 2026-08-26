import SwiftUI

/// The menu bar popover's content: a full mini player, always in its "expanded" state (there's
/// no hover-to-reveal here — clicking the menu bar icon already means the user wants the full
/// controls). Deliberately built from the same subviews as the HUD (`ArtworkThumbnail`,
/// `TransportControls`, `ScrubberView`, `SecondaryControlsRow`) so the two feel like one
/// consistent design language rather than a plain `NSMenu` bolted on the side.
public struct MiniPlayerView: View {
    var content: HUDContentModel
    weak var interactor: HUDInteracting?
    var onOpenSettings: () -> Void
    var onLaunchPlayer: () -> Void
    var isPlayerRunning: Bool

    public init(
        content: HUDContentModel, interactor: HUDInteracting?, isPlayerRunning: Bool,
        onOpenSettings: @escaping () -> Void, onLaunchPlayer: @escaping () -> Void
    ) {
        self.content = content
        self.interactor = interactor
        self.isPlayerRunning = isPlayerRunning
        self.onOpenSettings = onOpenSettings
        self.onLaunchPlayer = onLaunchPlayer
    }

    public var body: some View {
        VStack(spacing: 14) {
            if isPlayerRunning, content.track != nil {
                playerContent
            } else {
                emptyState
            }
            Divider()
            HStack {
                Button("Settings…", action: onOpenSettings)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var playerContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ArtworkThumbnail(image: content.artworkImage, size: 64, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.track?.title ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(content.track?.artist ?? "")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let album = content.track?.album, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            ScrubberView(
                estimator: content.progressEstimator, tint: .accentColor,
                isEnabled: content.capabilities.contains(.seek),
                onSeek: { interactor?.perform(.seek(to: $0)) }
            )
            TimeLabelsView(estimator: content.progressEstimator)

            TransportControls(
                isPlaying: content.state == .playing, size: 17,
                onPrevious: { interactor?.perform(.previous) },
                onPlayPause: { interactor?.perform(.playPause) },
                onNext: { interactor?.perform(.next) }
            )

            SecondaryControlsRow(
                volume: content.volume, shuffle: content.shuffle, repeatMode: content.repeatMode,
                capabilities: content.capabilities,
                onVolumeChange: { interactor?.perform(.setVolume($0)) },
                onToggleShuffle: { interactor?.perform(.setShuffle(!content.shuffle)) },
                onCycleRepeat: { interactor?.perform(.setRepeatMode(content.repeatMode.next(supporting: content.capabilities))) }
            )

            Button {
                interactor?.openInPlayer()
            } label: {
                Label("Open in \(content.track?.provider.displayName ?? "Player")", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
                .frame(height: 64)
            Text(isPlayerRunning ? "Nothing Playing" : "Player Not Running")
                .font(.system(size: 13, weight: .medium))
            if !isPlayerRunning {
                Button("Open Spotify", action: onLaunchPlayer)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
