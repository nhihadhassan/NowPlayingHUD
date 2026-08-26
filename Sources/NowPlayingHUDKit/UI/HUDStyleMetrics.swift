import Foundation
import SwiftUI

/// Layout constants derived from the appearance style + size preferences. Kept in one place so
/// the three styles read as genuinely distinct (per the "not a theme editor, but a small number
/// of genuinely good styles" brief) rather than one layout with a color swapped.
struct HUDStyleMetrics {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let contentSpacing: CGFloat
    let titleWeight: Font.Weight
    let showsStrongBackground: Bool

    init(style: HUDVisualStyle, size: HUDSize) {
        let scale: CGFloat
        switch size {
        case .small: scale = 0.88
        case .medium: scale = 1.0
        case .large: scale = 1.16
        }
        switch style {
        case .glass:
            cornerRadius = 20 * scale
            padding = 14 * scale
            contentSpacing = 3
            titleWeight = .semibold
            showsStrongBackground = true
        case .compact:
            cornerRadius = 14 * scale
            padding = 9 * scale
            contentSpacing = 1.5
            titleWeight = .medium
            showsStrongBackground = true
        case .minimal:
            cornerRadius = 24 * scale
            padding = 10 * scale
            contentSpacing = 2
            titleWeight = .medium
            showsStrongBackground = false
        }
    }
}
