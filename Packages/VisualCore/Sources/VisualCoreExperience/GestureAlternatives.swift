// GestureAlternatives.swift — every canvas gesture has a native control (feature 226, R02-F26 T-R02F26-006;
// FR-R02F26-010; Auto-Creator.md section 6.5 rule 3).

/// The check that a person who cannot perform a gesture reaches its result with a native control.
public enum GestureAlternatives {
    /// The actions a canvas gesture can send that no native control sends, sorted; empty when every gesture has an
    /// alternative.
    public static func missing(gesture: Set<String>, native: Set<String>) -> [String] {
        gesture.subtracting(native).sorted()
    }
}
