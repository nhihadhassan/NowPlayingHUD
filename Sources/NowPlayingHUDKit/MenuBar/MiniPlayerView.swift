import SwiftUI

/// The menu bar popover's content: a full mini player, always in its "expanded" state (there's
/// no hover-to-reveal here — clicking the menu bar icon already means the user wants the full
/// controls). Built from the same subviews as the HUD (`ArtworkThumbnail`, `TransportControls`,
/// `ScrubberView`, `SecondaryControlsRow`) so the two read as one design language, with a subtle
/// artwork-derived ambient wash behind the header — restrained (never above ~10% opacity, and
/// never relied on for contrast) rather than a decorative gradient sprayed across the whole card.
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
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ambientWash
                VStack(spacing: 16) {
                    if isPlayerRunning, content.track != nil {
                        playerContent
                    } else {
                        emptyState
                    }
                }
                .padding(16)
            }
            footer
        }
        .frame(width: 288)
    }

    // MARK: - Ambient wash

    @ViewBuilder
    private var ambientWash: some View {
        if let accent = content.accent {
            LinearGradient(
                colors: [Color(red: accent.red, green: accent.green, blue: accent.blue).opacity(0.16), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 150)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Player content

    private var playerContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ArtworkThumbnail(image: content.artworkImage, size: 68, cornerRadius: 15)
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(content.track?.title ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
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
            .contextMenu {
                Button("Copy Track Link") { interactor?.copyTrackLink() }
                Button("Copy “\(content.track?.title ?? "Track") — \(content.track?.artist ?? "Artist")”") {
                    interactor?.copyTrackAndArtist()
                }
            }

            VStack(spacing: 6) {
                ScrubberView(
                    estimator: content.progressEstimator, tint: accentColor,
                    isEnabled: content.capabilities.contains(.seek),
                    onSeek: { interactor?.perform(.seek(to: $0)) }
                )
                TimeLabelsView(estimator: content.progressEstimator)
            }

            TransportControls(
                isPlaying: content.state == .playing, size: 18,
                onPrevious: { interactor?.perform(.previous) },
                onPlayPause: { interactor?.perform(.playPause) },
                onNext: { interactor?.perform(.next) }
            )
            .frame(maxWidth: .infinity)

            Divider().opacity(0.5)

            SecondaryControlsRow(
                volume: content.volume, shuffle: content.shuffle, repeatMode: content.repeatMode,
                capabilities: content.capabilities, tint: accentColor,
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

    private var accentColor: Color {
        guard let accent = content.accent else { return .accentColor }
        return Color(red: accent.red, green: accent.green, blue: accent.blue)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
                .frame(height: 60)
            Text(isPlayerRunning ? "Nothing Playing" : "Spotify Isn’t Running")
                .font(.system(size: 13, weight: .medium))
            if !isPlayerRunning {
                Button("Open Spotify", action: onLaunchPlayer)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 2) {
            FooterButton(systemName: "gearshape", title: "Settings", action: onOpenSettings)
            Spacer(minLength: 0)
            FooterButton(systemName: "power", title: "Quit", action: { NSApp.terminate(nil) })
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }
}

/// A footer action with a subtle hover highlight — reads as a designed control rather than a
/// bare text link left over from an `NSMenu`.
private struct FooterButton: View {
    var systemName: String
    var title: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary.opacity(isHovering ? 1 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
