import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// A subtle accent color derived from artwork, expressed as plain component values (not
/// `NSColor`) so it can cross into SwiftUI as `Color(red:green:blue:)` without any AppKit
/// dependency at the call site.
public struct ArtworkAccent: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
}

/// Derives a tasteful, legibility-safe accent color from artwork using Core Image's
/// `CIAreaAverage` — a single averaged pixel, not a full palette-extraction pipeline, which
/// keeps this fast enough to run on every track change without a visible hitch.
///
/// The raw average is then pulled toward a narrow saturation/brightness band so the result reads
/// as a gentle tint rather than a jarring color, in both light and dark appearance — this is
/// used purely as a background/glass tint, never as text color, so legibility is never traded
/// away for it.
public enum AccentExtractor {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    public static func extractAccent(from image: NSImage) -> ArtworkAccent? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let ciImage = CIImage(cgImage: cgImage)

        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let outputImage = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage, toBitmap: &pixel, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: nil
        )

        let raw = ArtworkAccent(
            red: Double(pixel[0]) / 255.0,
            green: Double(pixel[1]) / 255.0,
            blue: Double(pixel[2]) / 255.0
        )
        return tamed(raw)
    }

    /// Clamps saturation and brightness into a subtle, tasteful band. Colors that are already
    /// muted or near-neutral (common for artwork with lots of white/black space) are left alone
    /// rather than pushed toward an artificial vibrancy.
    static func tamed(_ accent: ArtworkAccent) -> ArtworkAccent {
        var (h, s, b) = rgbToHSB(accent)
        s = min(s, 0.55)
        b = max(0.35, min(b, 0.8))
        return hsbToRGB(h: h, s: s, b: b)
    }

    private static func rgbToHSB(_ c: ArtworkAccent) -> (h: Double, s: Double, b: Double) {
        let maxV = max(c.red, c.green, c.blue)
        let minV = min(c.red, c.green, c.blue)
        let delta = maxV - minV
        let brightness = maxV
        let saturation = maxV == 0 ? 0 : delta / maxV

        var hue: Double = 0
        if delta > 0 {
            if maxV == c.red {
                hue = ((c.green - c.blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxV == c.green {
                hue = (c.blue - c.red) / delta + 2
            } else {
                hue = (c.red - c.green) / delta + 4
            }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        return (hue, saturation, brightness)
    }

    private static func hsbToRGB(h: Double, s: Double, b: Double) -> ArtworkAccent {
        let c = b * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c
        let (r, g, bl): (Double, Double, Double)
        switch h {
        case 0..<60: (r, g, bl) = (c, x, 0)
        case 60..<120: (r, g, bl) = (x, c, 0)
        case 120..<180: (r, g, bl) = (0, c, x)
        case 180..<240: (r, g, bl) = (0, x, c)
        case 240..<300: (r, g, bl) = (x, 0, c)
        default: (r, g, bl) = (c, 0, x)
        }
        return ArtworkAccent(red: r + m, green: g + m, blue: bl + m)
    }
}
