import SwiftUI

/// Embeds the real `HUDRootView` with a sample track so appearance changes are reflected
/// instantly — never a mocked-up screenshot-style preview. Deliberately always uses a fixed
/// sample rather than mirroring live playback: swapping the model out from under the view on
/// every real playback event would either lose the just-fetched artwork each time or require
/// mutating `@State` mid-render, for a benefit (showing your actual current track) the settings
/// window doesn't really need — it's the *appearance*, not the *content*, that's under test here.
struct HUDPreviewSection: View {
    @Bindable var preferences: PreferencesStore

    @State private var sampleModel = HUDContentModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Preview").font(.headline)
            HStack {
                Spacer()
                HUDRootView(content: sampleModel, options: options, interactor: nil)
                Spacer()
            }
            .padding(28)
            .background(Color(nsColor: .underPageBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .onAppear(perform: configureSampleIfNeeded)
    }

    private var options: HUDDisplayOptions {
        HUDDisplayOptions(
            style: preferences.hudStyle, size: preferences.hudSize,
            showAlbumArt: preferences.showAlbumArt, showTitle: preferences.showTitle,
            showArtist: preferences.showArtist, showAlbum: preferences.showAlbum,
            showProgress: preferences.showProgress, showTime: preferences.showTime,
            showControls: preferences.showControls, hoverToExpand: preferences.hoverToExpand,
            accentFromArtwork: preferences.accentFromArtwork, primaryClickAction: preferences.primaryClickAction
        )
    }

    private func configureSampleIfNeeded() {
        guard sampleModel.track == nil else { return }
        sampleModel.apply(PlaybackSnapshot(
            track: Track(
                id: "preview", provider: .spotify, title: "Sample Track Title", artist: "Sample Artist",
                album: "Sample Album", duration: .seconds(222)
            ),
            state: .playing, reportedPosition: 68, capturedAt: .now, volume: 72, shuffle: true,
            repeatMode: .all, capabilities: .spotify
        ))
        sampleModel.isVisible = true
    }
}
