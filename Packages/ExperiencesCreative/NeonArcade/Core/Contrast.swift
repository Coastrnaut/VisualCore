// Contrast — feature 079 (A10-P05) T-A10-502 (FR-A10-502; clarification 2; research D2; data-model "Contrast
// thresholds"). How readable the game's shapes are, measured as colour contrast: the sRGB relative luminance of WCAG
// 2.x (each channel linearised: c ≤ 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)^2.4; L = 0.2126 R + 0.7152 G +
// 0.0722 B), the ratio (L1 + 0.05) / (L2 + 0.05) with L1 the lighter, and straight-alpha "over" compositing to place a
// glow on the field. Thresholds: a hazard's core against the field ≥ 4.5 and against its own glow composited over the
// field at the level's opacity cap ≥ 3; the player's and the orbs' cores against the field ≥ 3. The reference
// background ``Contrast/field`` must equal the experience presenter's `ArcadePresenter.fieldColor` (an experience test
// ties them).
import Foundation
import VisualCoreMath

/// Colour contrast for Neon Arcade (colours are `Vec4` red, green, blue, alpha in 0…1).
public enum Contrast {
    /// The field colour every shape is drawn over; equal to `ArcadePresenter.fieldColor`.
    public static let field = Vec4(0.027, 0.024, 0.102, 1)
    /// The least ratio of a hazard's core against the field.
    public static let hazardVsField = 4.5
    /// The least ratio of a hazard's core against its glow composited over the field at the level's opacity cap.
    public static let hazardVsGlow = 3.0
    /// The least ratio of the player's and the orbs' cores against the field.
    public static let playerAndOrbVsField = 3.0

    /// One sRGB channel (0…1, clamped) in linear light.
    static func linear(_ c: Double) -> Double {
        let c = min(max(c.isFinite ? c : 0, 0), 1)
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// The relative luminance of `rgb` (alpha ignored), 0…1.
    public static func luminance(_ rgb: Vec4) -> Double {
        0.2126 * linear(rgb.x) + 0.7152 * linear(rgb.y) + 0.0722 * linear(rgb.z)
    }

    /// The contrast ratio of two colours (alpha ignored), 1…21, the same in either order.
    public static func ratio(_ a: Vec4, _ b: Vec4) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// `top` composited over `over` (straight alpha, Porter–Duff "over"); over an opaque colour the result is opaque.
    public static func composite(_ top: Vec4, over: Vec4) -> Vec4 {
        let ta = min(max(top.w, 0), 1), oa = min(max(over.w, 0), 1)
        let outA = ta + oa * (1 - ta)
        guard outA > 0 else { return .zero }
        func channel(_ t: Double, _ o: Double) -> Double { (t * ta + o * oa * (1 - ta)) / outA }
        return Vec4(channel(top.x, over.x), channel(top.y, over.y), channel(top.z, over.z), outA)
    }

    /// A catalog colour as a vector.
    public static func vector(_ color: RGBA) -> Vec4 { Vec4(color.r, color.g, color.b, color.a) }

    /// `item`'s glow colour at `opacity` (its own alpha replaced) composited over the field: the background right
    /// around the item's core at that glow opacity.
    public static func glowOverField(_ item: ContentItem, opacity: Double) -> Vec4 {
        let glow = vector(item.glowColor)
        return composite(Vec4(glow.x, glow.y, glow.z, opacity), over: field)
    }
}
