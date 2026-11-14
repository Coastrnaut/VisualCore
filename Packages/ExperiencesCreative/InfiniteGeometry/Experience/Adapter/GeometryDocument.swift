// GeometryDocument — feature 043 (A05-P04) T-A05-402 (FR-A05-401, FR-A05-402; data-model "GeometryDocument";
// contracts/api.md; clarification 1). A saved Infinite Geometry composition: the curated preset index, the whole preset
// (motif seed included) and both cameras, with a display name. The document is restored by one atomic action,
// `composition.open`, whose 18 values are `openValues` in a fixed order; the 64-bit motif seed is split into two
// 32-bit halves so every value is an exact Double and the digest after opening equals the digest at save time.
import Foundation
import InfiniteGeometryCore
import VisualCoreMath

/// A saved composition of Infinite Geometry (document version 1): the preset index, the preset and the two cameras of a
/// `GeometryCore`, with a cleaned display name.
public struct GeometryDocument: Codable, Equatable, Sendable {
    /// The document version this type writes; a larger version is newer and refused by the library.
    public static let version = 1
    /// The longest name a document keeps, in characters.
    public static let maxNameLength = 60
    /// The name of a document saved with an empty or blank name.
    public static let untitledName = "Untitled"
    /// The number of values of `openValues` and of the `composition.open` action.
    public static let openValueCount = 18

    /// The document version (1).
    public var version: Int
    /// The display name, trimmed, at most `maxNameLength` characters, never empty.
    public var name: String
    /// The index of the curated preset last selected.
    public var presetIndex: Int
    /// The whole preset, motif seed included.
    public var preset: GeometryPreset
    /// The 2D camera.
    public var view2D: GeometryCore.View2D
    /// The orbit camera.
    public var orbit3D: GeometryCore.Orbit3D

    /// The document of `core`'s current composition with the cleaned `name` (`clean(_:)`).
    public init(core: GeometryCore, name: String) {
        version = Self.version
        self.name = Self.clean(name)
        presetIndex = core.presetIndex
        preset = core.preset
        view2D = core.view2D
        orbit3D = core.orbit3D
    }

    /// `name` with surrounding whitespace and newlines removed, cut to `maxNameLength` characters; an empty result is
    /// `untitledName`. Saving is therefore never refused for its name.
    public static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cut = String(trimmed.prefix(maxNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return cut.isEmpty ? untitledName : cut
    }

    /// The values of `composition.open`, in this order: preset index, kind (index in `GeometryPreset.Kind.allCases`),
    /// order, repeats, scale, palette, seed high 32 bits, seed low 32 bits, 2D centre x, centre y, zoom, orbit yaw,
    /// pitch, distance, target x, y, z, field of view in degrees. Every value is exact.
    public var openValues: [Double] {
        let kind = GeometryPreset.Kind.allCases.firstIndex(of: preset.kind) ?? 0
        return [Double(presetIndex), Double(kind), Double(preset.order), Double(preset.repeats), preset.scale,
                Double(preset.palette), Double(UInt32(truncatingIfNeeded: preset.seed >> 32)),
                Double(UInt32(truncatingIfNeeded: preset.seed)),
                view2D.centerX, view2D.centerY, view2D.zoom,
                orbit3D.yaw, orbit3D.pitch, orbit3D.distance, orbit3D.targetX, orbit3D.targetY, orbit3D.targetZ,
                orbit3D.fovDegrees]
    }

    /// The document carried by `values` (the layout of `openValues`) with the cleaned `name`; nil when the count is not
    /// `openValueCount`, a value is not finite, or a value lies outside `openRanges` or is not a whole number where one
    /// is needed (`firstInvalidIndex(in:)`). Whether the camera fits the built composition is checked by the core.
    public init?(openValues values: [Double], name: String) {
        guard values.count == Self.openValueCount, values.allSatisfy(\.isFinite),
              Self.firstInvalidIndex(in: values) == nil else { return nil }
        let kinds = GeometryPreset.Kind.allCases
        let kindIndex = Int(values[1])
        guard kinds.indices.contains(kindIndex) else { return nil }
        let seed = UInt64(UInt32(values[6])) << 32 | UInt64(UInt32(values[7]))
        version = Self.version
        self.name = Self.clean(name)
        presetIndex = Int(values[0])
        preset = GeometryPreset(kind: kinds[kindIndex], order: Int(values[2]), repeats: Int(values[3]),
                                scale: values[4], palette: Int(values[5]), seed: seed)
        view2D = GeometryCore.View2D(centerX: values[8], centerY: values[9], zoom: values[10])
        orbit3D = GeometryCore.Orbit3D(yaw: values[11], pitch: values[12], distance: values[13],
                                       target: Vec3(values[14], values[15], values[16]), fovDegrees: values[17])
    }

    /// The coarse range of each open value: the preset ranges of `GeometryPreset`, the seed halves 0…2³²−1, the 2D
    /// centre within the widest extent (±1/0.25), the zoom range, yaw ±π, the pitch and distance bounds, the target
    /// within ±`targetRadius` per axis and the field-of-view range. The exact camera bounds of the built composition
    /// are a separate rule check in the core.
    public static var openRanges: [ClosedRange<Double>] {
        let extent = 1 / GeometryPreset.scaleRange.lowerBound
        let pitch = GeometryCore.orbitBounds.pitchLimit
        let target = GeometryCore.targetRadius
        return [0...Double(GeometryPreset.curated.count - 1), 0...Double(GeometryPreset.Kind.allCases.count - 1),
                whole(GeometryPreset.orderRange), whole(GeometryPreset.repeatsRange), GeometryPreset.scaleRange,
                whole(GeometryPreset.paletteRange), 0...Double(UInt32.max), 0...Double(UInt32.max),
                -extent...extent, -extent...extent, GeometryCore.zoomRange,
                -Double.pi...Double.pi, -pitch...pitch, GeometryCore.orbitBounds.distanceRange,
                -target...target, -target...target, -target...target, GeometryCore.fovRange]
    }

    /// The indices of `openValues` that must be whole numbers: preset index, kind, order, repeats, palette and the two
    /// seed halves.
    public static let wholeIndices: Set<Int> = [0, 1, 2, 3, 5, 6, 7]

    /// The first index of `values` (assumed `openValueCount` finite values) that lies outside its `openRanges` entry
    /// or is not a whole number where `wholeIndices` needs one; nil when every value is acceptable.
    public static func firstInvalidIndex(in values: [Double]) -> Int? {
        for (index, pair) in zip(values, openRanges).enumerated() {
            if !pair.1.contains(pair.0) || (wholeIndices.contains(index) && pair.0.rounded() != pair.0) {
                return index
            }
        }
        return nil
    }

    /// An integer range as a closed range of doubles.
    private static func whole(_ r: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(r.lowerBound)...Double(r.upperBound)
    }
}
