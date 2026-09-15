import SwiftUI

/// Settings the view needs but that live in `PreferencesStore` — passed down as a small value
/// type rather than the whole store, so this view doesn't need to import/depend on the
/// Preferences module's persistence details.
public struct HUDDisplayOptions: Equatable {
    public var style: HUDVisualStyle
    public var size: HUDSize
    public var showAlbumArt: Bool
    public var showTitle: Bool
    public var showArtist: Bool
    public var showAlbum: Bool
    public var showProgress: Bool
    public var showTime: Bool
    public var showControls: Bool
    public var hoverToExpand: Bool
    public var accentFromArtwork: Bool
    public var primaryClickAction: HUDClickAction

    public init(
        style: HUDVisualStyle, size: HUDSize, showAlbumArt: Bool, showTitle: Bool, showArtist: Bool,
        showAlbum: Bool, showProgress: Bool, showTime: Bool, showControls: Bool, hoverToExpand: Bool,
        accentFromArtwork: Bool, primaryClickAction: HUDClickAction
    ) {
        self.style = style
        self.size = size
        self.showAlbumArt = showAlbumArt
        self.showTitle = showTitle
        self.showArtist = showArtist
        self.showAlbum = showAlbum
        self.showProgress = showProgress
        self.showTime = showTime
        self.showControls = showControls
        self.hoverToExpand = hoverToExpand
        self.accentFromArtwork = accentFromArtwork
        self.primaryClickAction = primaryClickAction
    }

    public static let `default` = HUDDisplayOptions(
        style: .glass, size: .medium, showAlbumArt: true, showTitle: true, showArtist: true,
        showAlbum: true, showProgress: true, showTime: true, showControls: true, hoverToExpand: true,
        accentFromArtwork: true, primaryClickAction: .openInPlayer
    )
}

/// The Now Playing HUD's content. Compact by default (artwork, title, artist, a subtle progress
/// bar); hovering progressively reveals transport controls, a scrubber, and volume/shuffle/
/// repeat — never a full player on every track change.
public struct HUDRootView: View {
    var content: HUDContentModel
    var options: HUDDisplayOptions
    weak var interactor: HUDInteracting?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(content: HUDContentModel, options: HUDDisplayOptions, interactor: HUDInteracting?) {
        self.content = content
        self.options = options
        self.interactor = interactor
    }

    private var metrics: HUDStyleMetrics { HUDStyleMetrics(style: options.style, size: options.size) }
    private var isExpanded: Bool { options.hoverToExpand && content.isHovering && options.showControls }

    public var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 0) {
            headerRow
            if isExpanded {
                expandedControls
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(metrics.padding)
        .frame(width: options.size.compactWidth)
        .background(
            metrics.showsStrongBackground
                ? AnyView(HUDBackground(cornerRadius: metrics.cornerRadius, tint: accentTint, isInteractive: content.isHovering))
                : AnyView(HUDBackground(cornerRadius: metrics.cornerRadius, tint: accentTint, isInteractive: content.isHovering).opacity(0.85))
        )
        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .scaleEffect(content.isVisible ? 1 : (reduceMotion ? 1 : 0.92))
        .opacity(content.isVisible ? 1 : 0)
        .offset(y: content.isVisible ? 0 : (reduceMotion ? 0 : -6))
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.4, dampingFraction: 0.86), value: content.isVisible)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .easeOut(duration: 0.28), value: isExpanded)
        .onHover { hovering in
            content.isHovering = hovering
            interactor?.hoverStateChanged(isHovering: hovering)
        }
        .onTapGesture { interactor?.primaryClickTriggered() }
        .contextMenu { contextMenuItems }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header (always visible)

    private var headerRow: some View {
        HStack(spacing: 12) {
            if options.showAlbumArt {
                ArtworkThumbnail(image: content.artworkImage, size: options.size.artworkSize, cornerRadius: metrics.cornerRadius * 0.55)
                    .shadow(color: .black.opacity(0.24), radius: 4, y: 2)
            }
            VStack(alignment: .leading, spacing: metrics.contentSpacing) {
                if options.showTitle {
                    Text(content.track?.title ?? "Nothing Playing")
                        .font(.system(size: titleFontSize, weight: metrics.titleWeight))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if options.showArtist, let artist = content.track?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: subtitleFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if options.showAlbum, let album = content.track?.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: subtitleFontSize - 1))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if options.showProgress && !isExpanded {
                    ProgressBarView(estimator: content.progressEstimator, tint: accentColor)
                        .padding(.top, 2)
                    if options.showTime {
                        HStack {
                            Spacer(minLength: 0)
                            RemainingTimeLabel(estimator: content.progressEstimator)
                        }
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            if !isExpanded {
                Image(systemName: content.state == .playing ? "waveform" : "pause.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.variableColor.iterative, isActive: content.state == .playing)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Expanded (on hover)

    private var expandedControls: some View {
        VStack(spacing: 10) {
            if options.showProgress {
                ScrubberView(
                    estimator: content.progressEstimator, tint: accentColor,
                    isEnabled: content.capabilities.contains(.seek),
                    onSeek: { interactor?.perform(.seek(to: $0)) }
                )
            }
            if options.showTime {
                TimeLabelsView(estimator: content.progressEstimator)
            }
            HStack {
                TransportControls(
                    isPlaying: content.state == .playing,
                    onPrevious: { interactor?.perform(.previous) },
                    onPlayPause: { interactor?.perform(.playPause) },
                    onNext: { interactor?.perform(.next) }
                )
                Spacer()
                Button {
                    interactor?.openInPlayer()
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open in \(content.track?.provider.displayName ?? "Player")")
                .accessibilityLabel("Open in \(content.track?.provider.displayName ?? "Player")")
            }
            SecondaryControlsRow(
                volume: content.volume, shuffle: content.shuffle, repeatMode: content.repeatMode,
                capabilities: content.capabilities, tint: accentColor,
                onVolumeChange: { interactor?.perform(.setVolume($0)) },
                onToggleShuffle: { interactor?.perform(.setShuffle(!content.shuffle)) },
                onCycleRepeat: { interactor?.perform(.setRepeatMode(content.repeatMode.next(supporting: content.capabilities))) }
            )
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Open in \(content.track?.provider.displayName ?? "Player")") { interactor?.openInPlayer() }
        Button("Copy Track Link") { interactor?.copyTrackLink() }
        Button("Copy “\(content.track?.title ?? "Track") — \(content.track?.artist ?? "Artist")”") {
            interactor?.copyTrackAndArtist()
        }
        Button("Show Player") { interactor?.showMiniPlayerRequested() }
        Divider()
        Button("Disable Automatic HUD Temporarily") { interactor?.disableAutomaticHUDTemporarily() }
        Divider()
        Button("Dismiss") { interactor?.dismissRequested() }
    }

    // MARK: - Derived values

    private var accentColor: Color {
        guard options.accentFromArtwork, let tint = content.accent else { return .primary }
        return Color(red: tint.red, green: tint.green, blue: tint.blue)
    }

    private var accentTint: ArtworkAccent? {
        options.accentFromArtwork ? content.accent : nil
    }

    private var titleFontSize: CGFloat {
        switch options.size {
        case .small: return 12.5
        case .medium: return 13.5
        case .large: return 15
        }
    }

    private var subtitleFontSize: CGFloat {
        switch options.size {
        case .small: return 11
        case .medium: return 11.5
        case .large: return 12.5
        }
    }

    private var accessibilitySummary: String {
        guard let track = content.track else { return "Nothing playing" }
        let stateText = content.state == .playing ? "Playing" : "Paused"
        return "\(stateText): \(track.title) by \(track.artist)"
    }
}
