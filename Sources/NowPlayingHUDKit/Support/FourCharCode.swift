import Foundation

/// Packs up to 4 ASCII characters into the `OSType`/`FourCharCode` form Carbon and Apple Event
/// APIs use throughout (`EventHotKeyID.signature`, AppleScript property codes, etc.).
func fourCharCode(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for byte in string.utf8.prefix(4) {
        result = (result << 8) | UInt32(byte)
    }
    return result
}
