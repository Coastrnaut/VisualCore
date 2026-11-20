# Contract: public API (R02-F11)

VisualCoreScenes (pure):
- `public indirect enum SDFShape: Sendable, Equatable` — cases of data-model.md; makers `static func plane(normal:offset:) throws(SDFError) -> SDFShape`, `sphere(radius:)`, `box(halfExtents:)`, `roundedBox(halfExtents:radius:)`, `capsule(a:b:radius:)`, `torus(major:minor:)`, `union(_:)`, `intersection(_:)`, `subtraction(_:_:)`, `smoothUnion(_:_:radius:)`, and instance `translated(by:)`, `rotated(by:)`, `scaled(by:)` (all `throws(SDFError)`); `public static let maxNodes = 256`, `maxDepth = 32`; `public var nodeCount: Int`, `public var depth: Int`; `public func distance(at p: Vec3) -> Double`; `public func normal(at p: Vec3) -> Vec3`; `public func contains(_ p: Vec3) -> Bool` (d < 0).
- `public struct SDFMarchOptions: Sendable, Equatable { public enum Mode: String, Sendable, Codable { case conservative, fast }; mode, maxSteps, maxDistance, tolerance; public init(mode: Mode = .conservative, maxSteps: Int = 128, maxDistance: Double = 100, tolerance: Double = 1e-7) throws(SDFError); public static let standard: SDFMarchOptions }` (`standard` = the defaults, conservative)
- `public struct SDFMarchResult: Sendable, Equatable { public enum Outcome: String, Sendable { case hit, miss, budgetExhausted }; outcome, distance, point, normal, steps, startedInside }`
- `public enum SDFMarch { public static func march(_ shape: SDFShape, ray: Ray3, options: SDFMarchOptions = .standard) -> SDFMarchResult }`
- `public struct SDFVolumeSample: Sendable, Equatable`; `public enum SDFVolume { public static func sample(_ shape: SDFShape, boundsMin: Vec3, boundsMax: Vec3, resolution: Int) throws(SDFError) -> SDFVolumeSample }`
- `public struct SDFDocument: Sendable, Equatable, Codable { public static let schema = 1; public let shape: SDFShape; public init(shape:); public func encoded() throws -> Data; public static func decode(_ data: Data) throws(SDFError) -> SDFDocument }`
- `public enum SDFError: Error, Equatable, Sendable { …; public var reasonCode: String }`
- `extension SDFShape { public func glslFunction(name: String = "vc_sdfShape") -> String }` — a GLSL ES 3.00 function `float <name>(vec3 p)` that needs `#include "vc/sdf.glsl"` and `#include "vc/sdfshape.glsl"`.

GLSL (`vc/sdfshape.glsl`): `float vc_sdPlane(vec3 p, vec3 n, float h)`, `float vc_sdRoundBox(vec3 p, vec3 b, float r)`,
`float vc_sdCapsule(vec3 p, vec3 a, vec3 b, float r)`, `float vc_opUnion(float a, float b)`, `float vc_opIntersect(float
a, float b)`, `float vc_opSubtract(float a, float b)`, `float vc_opSmoothUnion(float a, float b, float k)` (k = 0 → min).
