import AppKit
import SwiftUI

/// `NSVisualEffectView` bridge, used as the pre-Liquid-Glass HUD material (`.hudWindow`,
/// `.behindWindow` blending) on macOS 14/15.
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// The HUD's background material: real Liquid Glass (`NSGlassEffectView`/SwiftUI `glassEffect`)
/// where the running macOS supports it, an HUD-style vibrancy material otherwise, or a flat
/// opaque fill when the user has Reduce Transparency on. Glass is applied here — to the single
/// container behind all the content — and nowhere else in the HUD, per "use it for hierarchy,
/// not decoration overload."
struct HUDBackground: View {
    var cornerRadius: CGFloat
    var tint: ArtworkAccent?
    var isInteractive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            shape.fill(Color(nsColor: .windowBackgroundColor))
        } else if #available(macOS 26.0, *) {
            GlassEffectContainer {
                Color.clear.glassEffect(glassStyle, in: shape)
            }
        } else {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(tintColor?.opacity(0.35) ?? .clear, lineWidth: 1)
                )
        }
    }

    @available(macOS 26.0, *)
    private var glassStyle: Glass {
        let base = Glass.regular
        let tinted = tintColor.map { base.tint($0) } ?? base
        return isInteractive ? tinted.interactive() : tinted
    }

    private var tintColor: Color? {
        guard let tint else { return nil }
        return Color(red: tint.red, green: tint.green, blue: tint.blue)
    }
}
