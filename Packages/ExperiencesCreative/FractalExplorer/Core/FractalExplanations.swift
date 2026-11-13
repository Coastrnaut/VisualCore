// FractalExplanations.swift — the short, educational mode explanations shown and spoken in the explorer (feature 026
// T-A03-103; FR-A03-101). Educational wording, never research-grade claims (constitution A03).

/// What each mode draws, in plain language.
public enum FractalExplanations {
    /// The explanation for `mode`.
    public static func text(for mode: FractalMode) -> String {
        switch mode {
        case .mandelbrot:
            return "Each point c of the plane is tested with the rule z → z² + c, starting from z = 0. "
                + "Points whose values stay bounded belong to the Mandelbrot set and are drawn black; the shade "
                + "outside shows how quickly a point escapes."
        case .julia:
            return "The same rule z → z² + c, but c is a fixed seed and each point of the plane is a starting z. "
                + "When the seed lies inside the Mandelbrot set, its Julia set is connected; seeds outside give "
                + "scattered dust."
        }
    }
}
