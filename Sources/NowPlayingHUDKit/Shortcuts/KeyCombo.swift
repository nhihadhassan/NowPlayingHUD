import Carbon
import Foundation
import AppKit

/// A key + modifier combination, storage-agnostic of AppKit/Carbon's differing representations:
/// `carbonModifiers` is what `RegisterEventHotKey` needs; conversion from/to `NSEvent
/// .ModifierFlags` (what the recorder UI captures) happens at the edges.
public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public let keyCode: UInt32
    /// Carbon modifier mask (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`, bitwise-OR'd).
    public let carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    public init?(keyCode: UInt32, cocoaModifiers: NSEvent.ModifierFlags) {
        guard !cocoaModifiers.isEmpty else { return nil } // require at least one modifier
        self.keyCode = keyCode
        self.carbonModifiers = Self.carbonModifiers(from: cocoaModifiers)
    }

    static func carbonModifiers(from cocoa: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if cocoa.contains(.command) { result |= UInt32(cmdKey) }
        if cocoa.contains(.option) { result |= UInt32(optionKey) }
        if cocoa.contains(.control) { result |= UInt32(controlKey) }
        if cocoa.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// A human-readable combo string in the conventional macOS symbol order, e.g. "⌃⌥⇧⌘9".
    public var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "\u{2303}" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "\u{2325}" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "\u{21E7}" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "\u{2318}" }
        result += Self.keyName(for: keyCode)
        return result
    }

    /// Named keys that don't have a sensible printable character (arrows, function keys, etc.),
    /// keyed by Carbon virtual keycode. Everything else falls back to `UCKeyTranslate` so labels
    /// respect the user's actual keyboard layout.
    private static let namedKeys: [UInt32: String] = [
        36: "\u{21A9}",  // Return
        48: "\u{21E5}",  // Tab
        49: "Space",
        51: "\u{232B}",  // Delete (backspace)
        53: "\u{238B}",  // Escape
        76: "\u{2324}",  // Enter (numpad)
        117: "\u{2326}", // Forward Delete
        123: "\u{2190}", // Left Arrow
        124: "\u{2192}", // Right Arrow
        125: "\u{2193}", // Down Arrow
        126: "\u{2191}", // Up Arrow
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    private static func keyName(for keyCode: UInt32) -> String {
        if let named = namedKeys[keyCode] { return named }
        if let character = translatedCharacter(for: keyCode), !character.isEmpty {
            return character.uppercased()
        }
        return "Key \(keyCode)"
    }

    /// Translates a virtual keycode to the character it produces under the user's current
    /// keyboard layout, via Carbon's `UCKeyTranslate` — the same mechanism AppKit itself uses
    /// internally, so labels stay correct on non-US layouts.
    private static func translatedCharacter(for keyCode: UInt32) -> String? {
        guard let sourceUnmanaged = TISCopyCurrentASCIICapableKeyboardLayoutInputSource() else { return nil }
        let source = sourceUnmanaged.takeRetainedValue()
        guard let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { rawBuffer -> OSStatus in
            guard let keyLayoutPointer = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                keyLayoutPointer, UInt16(keyCode), UInt16(kUCKeyActionDown), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, chars.count, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
