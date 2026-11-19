# Contract: public API (R02-F10)

VisualCoreParameters (pure):
- `public enum PerceptualColor { static func linear(fromSRGB: SIMD3<Double>) -> SIMD3<Double>; static func sRGB(fromLinear: SIMD3<Double>) -> SIMD3<Double>; static func oklab(fromLinear: SIMD3<Double>) -> SIMD3<Double>; static func linear(fromOklab: SIMD3<Double>) -> SIMD3<Double>; static func oklch(fromOklab: SIMD3<Double>) -> SIMD3<Double>; static func oklab(fromOklch: SIMD3<Double>) -> SIMD3<Double>; static func relativeLuminance(sRGB: SIMD3<Double>) -> Double; static func lightness(sRGB: SIMD3<Double>) -> Double; static func contrastRatio(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double; static func difference(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double; static func rotateHue(sRGB: SIMD3<Double>, by radians: Double) throws(ColorAccessError) -> SIMD3<Double>; static func intoGamut(oklch: SIMD3<Double>) -> SIMD3<Double> }`
- `public enum ColorVisionCondition: String, CaseIterable, Sendable, Codable { case normal, protanopia, deuteranopia, tritanopia, achromatopsia; public var matrix: [SIMD3<Double>]; public func simulate(sRGB: SIMD3<Double>) -> SIMD3<Double> }`
- `public struct PaletteSeparationIssue: Sendable, Equatable { first, second: Int; condition: ColorVisionCondition; distance: Double }`
- `public enum PaletteSeparation { public static let threshold = 0.08; public static func issues(_ colors: [SIMD3<Double>]) -> [PaletteSeparationIssue] }`
- `public enum ColorVisionPresets { public static let warmCool, redCyan, lightness: Palette; public static let all: [Palette] }`
- `public enum ClueShape: Int, CaseIterable, Sendable, Codable`; `public enum CluePattern: Int, CaseIterable, Sendable, Codable`
- `public struct CodedState: Sendable, Equatable, Codable { id, color, shape, pattern, name }`
- `public struct CodedStateSet: Sendable, Equatable { public static let maxStates = 32; public let states: [CodedState]; public init(_ states: [CodedState]) throws(ColorAccessError); public var separationIssues: [PaletteSeparationIssue] }`
- `public enum ClueReference { public static func distance(shape: ClueShape, at p: SIMD2<Double>) -> Double; public static func pattern(_ pattern: CluePattern, at p: SIMD2<Double>) -> Double; public static func coverage(shape: ClueShape, pattern: CluePattern, at p: SIMD2<Double>, antialias: Double) -> Double }`
- `public enum ColorAccessError: Error, Equatable, Sendable { …; public var reasonCode: String }`

VisualCoreSimulation: `public enum ColorVisionChoice: String, Sendable, Codable, CaseIterable, Identifiable { case standard, warmCool, redCyan, lightness; init(storedValue: String?); var title: String }`; `AccessibilityPreferences.colorVision`; `init(reduceMotion:reduceFlashing:colorVision:)` with defaults; `static func colorVisionKey(prefix:) -> String`.

VisualCoreUI: `public struct ClueBadge: View { init(state: CodedState, size: CGFloat = 28) }` (spoken label = name);
`ColorVisionChoice.palette: Palette?` (nil for `standard`); `AccessibilitySettingsSection` shows a colour-vision picker
with identifier `<prefix>.colorVision`.

GLSL (`#include "vc/spectral.glsl"`, `"vc/clue.glsl"`): `vec3 vc_linearToOklab(vec3)`, `vec3 vc_oklabToLinear(vec3)`,
`vec3 vc_hueRotate(vec3 linearRGB, float radians)`, `vec3 vc_simulateCVD(vec3 linearRGB, int condition)`,
`float vc_clueShape(vec2 p, int shape)`, `float vc_cluePattern(vec2 p, int pattern)`,
`float vc_clueCoverage(vec2 p, int shape, int pattern, float aa)`.
