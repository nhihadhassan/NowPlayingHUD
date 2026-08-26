import AppKit
import SwiftUI

/// Album artwork with a graceful placeholder and a crossfade between images, sized up front so
/// nothing reflows while a new piece of artwork is loading.
struct ArtworkThumbnail: View {
    var image: NSImage?
    var size: CGFloat
    var cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                    .id(ObjectIdentifier(image))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.38, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeOut(duration: 0.35), value: image.map(ObjectIdentifier.init))
        .accessibilityHidden(true) // the track/artist text carries the meaning for VoiceOver
    }
}
