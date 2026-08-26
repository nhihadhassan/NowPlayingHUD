import Foundation

extension Int {
    /// `Swift.min`/`Swift.max` are qualified deliberately: inside an `Int` extension, the bare
    /// names `min`/`max` resolve to the static properties `Int.min`/`Int.max` (the type's own
    /// members shadow the global generic functions), not the comparison functions.
    func clamped(_ range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
