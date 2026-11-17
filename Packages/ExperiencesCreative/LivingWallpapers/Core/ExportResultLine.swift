// ExportResultLine — feature 140 (A19-P03) T-A19-305 (FR-A19-303; clarification Q3). The one line shown after a
// written export, built from the file read back through ImageIO: "<FORMAT>, <W> × <H> pixels, <profile>", for example
// "PNG, 1206 × 2622 pixels, sRGB". Pure text.
import Foundation

/// The line that describes a written export.
public enum ExportResultLine {
    /// "<FORMAT>, <W> × <H> pixels, <profile>": the format from `plan` (PNG, JPEG or HEIC), the pixel size from
    /// `result` (the read-back file), and the profile shown as "sRGB" when `result.profileName` is
    /// `kCGColorSpaceSRGB`, by its name otherwise, or as "unknown profile" when the file has none.
    public static func line(plan: ExportPlan, result: ExportResult) -> String {
        let profile: String
        if let name = result.profileName {
            profile = name == ColorProfile.sRGB.name ? "sRGB" : name
        } else {
            profile = "unknown profile"
        }
        return "\(plan.format.rawValue.uppercased()), \(result.width) × \(result.height) pixels, \(profile)"
    }
}
