// Generates NowPlayingHUD's app icon as a full .iconset + .icns, using only Core Graphics/AppKit
// and a system SF Symbol glyph — no external image assets or tools beyond Apple's own `iconutil`.
//
// Usage: swift Tools/GenerateIcon.swift <output-iconset-dir>
// The Makefile then runs `iconutil -c icns` on the resulting .iconset directory.

import AppKit
import CoreGraphics

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: GenerateIcon.swift <output.iconset directory>\n".utf8))
    exit(1)
}
let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// (filename, point size, scale)
let specs: [(String, CGFloat, CGFloat)] = [
    ("icon_16x16.png", 16, 1), ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1), ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1), ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1), ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1), ("icon_512x512@2x.png", 512, 2)
]

func drawIcon(pixelSize: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let context = NSGraphicsContext.current?.cgContext else { return nil }

    let size = CGFloat(pixelSize)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // macOS "squircle" (continuous corner) app icon shape, at Apple's standard ~22.5% corner ratio.
    let cornerRadius = size * 0.225
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(path)
    context.clip()

    // A deep, "now playing at night" gradient — indigo to violet — distinct from Spotify's own
    // green so the icon reads as its own app, not a clone.
    let colors = [
        NSColor(calibratedRed: 0.20, green: 0.14, blue: 0.46, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.46, green: 0.22, blue: 0.62, alpha: 1.0).cgColor
    ]
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
        context.drawLinearGradient(
            gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: []
        )
    }

    // Subtle top highlight for depth, matching a soft glass-like sheen rather than a flat fill.
    context.saveGState()
    let highlightPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(highlightPath)
    context.clip()
    if let highlightGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [NSColor.white.withAlphaComponent(0.22).cgColor, NSColor.white.withAlphaComponent(0.0).cgColor] as CFArray,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            highlightGradient, start: CGPoint(x: size / 2, y: size), end: CGPoint(x: size / 2, y: size * 0.45), options: []
        )
    }
    context.restoreGState()

    // A waveform glyph, centered — evokes "now playing" without literally cloning any specific
    // player's logo.
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        NSColor.white.withAlphaComponent(0.96).set()
        let imageRect = CGRect(origin: .zero, size: symbol.size)
        symbol.draw(in: imageRect)
        imageRect.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let symbolSize = symbol.size
        let scaleToFit = (size * 0.56) / max(symbolSize.width, symbolSize.height)
        let drawSize = CGSize(width: symbolSize.width * scaleToFit, height: symbolSize.height * scaleToFit)
        let origin = CGPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
        tinted.draw(in: CGRect(origin: origin, size: drawSize))
    }

    return rep
}

for (filename, pointSize, scale) in specs {
    let pixelSize = Int(pointSize * scale)
    guard let rep = drawIcon(pixelSize: pixelSize), let pngData = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("Failed to render \(filename)\n".utf8))
        exit(1)
    }
    let url = outputDir.appendingPathComponent(filename)
    try? pngData.write(to: url)
    print("wrote \(filename) (\(pixelSize)x\(pixelSize))")
}
