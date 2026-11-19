// CurveMeshes.swift — feature 208 (R02-F08) T-R02F08-004 (FR-R02F08-004, FR-R02F08-005; research R4, R5; spec
// Clarifications Q4, Q5; data-model "Ribbon mesh"). Ribbons and tubes along curve samples with texture coordinates in
// world units, and the merge of many meshes into one for a single draw. Exact counts are checked against the budget
// before anything is built; vertices are not welded, so counts are exactly as documented.
import Foundation
import VisualCoreMath

/// The width of a ribbon: one value for the whole ribbon or one value per sample.
public enum RibbonWidth: Sendable, Equatable {
    /// The same width at every sample (finite, positive).
    case constant(Double)
    /// One width per sample, in sample order (each finite, positive; as many as there are samples).
    case perSample([Double])
}

extension Mesh {
    /// A ribbon along `samples` (clarification Q4; data-model "Ribbon mesh").
    ///
    /// Frames come from `CurveFrames.parallelTransport(samples, initialNormal:)`. Each sample i gives two vertices,
    /// `position − binormal × w/2` (u = 0) and `position + binormal × w/2` (u = 1), both with the frame normal as
    /// surface normal and v = arcLength(i) / repeat. For an open record repeat = `repeatLength`; for a closed record it
    /// becomes `L / max(1, round(L / repeatLength))` (L the loop length) so a whole number of repeats fits, and a seam
    /// pair repeats the first sample's vertices with v = L / repeat. Between consecutive pairs two triangles wind
    /// counter-clockwise seen from the side the frame normal points to. The ribbon is an open surface; its boundary
    /// is the two long sides (and the end edges of an open record). Texture v exceeds 1 when the curve is longer than
    /// one repeat (tiled coordinates; `Mesh.validate` then reports `uvOutOfRange` for those vertices).
    ///
    /// - Returns: 2 · (count + seam) vertices and 6 · (count + seam − 1) indices, seam = 1 for a closed record.
    /// - Throws: `.invalidInput` for a width that is not finite and positive, a per-sample width count different from
    ///   the sample count, a `repeatLength` that is not finite and positive or a non-finite `initialNormal`;
    ///   `.budget` when the exact counts exceed `budget`.
    public static func ribbon(_ samples: CurveSamples, width: RibbonWidth, repeatLength: Double = 1,
                              initialNormal: Vec3? = nil, budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        let count = samples.positions.count
        let widths: [Double]
        switch width {
        case .constant(let w): widths = Array(repeating: w, count: count)
        case .perSample(let values):
            guard values.count == count else {
                throw .invalidInput("ribbon needs \(count) widths, got \(values.count)")
            }
            widths = values
        }
        guard widths.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw .invalidInput("ribbon width must be finite and positive")
        }
        let repeatSize = try curveRepeat(samples, repeatLength)
        let rings = count + (samples.isClosed ? 1 : 0)
        try checkCurveBudget(vertices: 2 * rings, indices: 6 * (rings - 1), budget: budget)

        let frames = try CurveFrames.parallelTransport(samples, initialNormal: initialNormal)
        var positions: [Vec3] = [], normals: [Vec3] = [], uvs: [Vec2] = [], indices: [UInt32] = []
        positions.reserveCapacity(2 * rings); normals.reserveCapacity(2 * rings); uvs.reserveCapacity(2 * rings)
        indices.reserveCapacity(6 * (rings - 1))
        for i in 0..<rings {
            let seam = i == count
            let f = frames[i]
            let half = widths[seam ? 0 : i] / 2
            let v = (seam ? samples.length : samples.arcLengths[i]) / repeatSize
            positions.append(f.position - f.binormal * half); normals.append(f.normal); uvs.append(Vec2(0, v))
            positions.append(f.position + f.binormal * half); normals.append(f.normal); uvs.append(Vec2(1, v))
        }
        for i in 0..<(rings - 1) {
            let l0 = UInt32(2 * i), r0 = l0 + 1, l1 = l0 + 2, r1 = l0 + 3
            indices += [l0, r0, l1, r0, r1, l1]
        }
        return Mesh(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }

    /// A tube of `radius` along `samples`, with the frames and texture v of `ribbon` (clarification Q4).
    ///
    /// `sides` is clamped to 3…256 like `tube(path:radius:sides:caps:closed:budget:)`. Frames come from
    /// `CurveFrames.parallelTransport(samples)`. Each sample gets a ring of `sides + 1` vertices (the seam vertex
    /// duplicated with u = 1) at `position + (normal cos θ + binormal sin θ) × radius`, outward normal
    /// `normal cos θ + binormal sin θ`, u = k / sides and v = arcLength / repeat (repeat as in `ribbon`); a closed
    /// record adds a seam ring at the first sample with v = L / repeat. Triangles wind counter-clockwise seen from
    /// outside. An open record with `caps` gets a fan at each end with normals ∓ the end tangent and texture
    /// coordinates on the unit disc around (0.5, 0.5); a closed record ignores `caps`.
    ///
    /// - Throws: `.invalidInput` for a radius or `repeatLength` that is not finite and positive; `.budget` when the
    ///   exact counts exceed `budget`.
    public static func tube(samples: CurveSamples, radius: Double, sides: Int, caps: Bool, repeatLength: Double = 1,
                            budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        guard radius.isFinite, radius > 0 else { throw .invalidInput("tube radius must be finite and positive") }
        let repeatSize = try curveRepeat(samples, repeatLength)
        let count = samples.positions.count
        let n = min(max(sides, tubeSideRange.lowerBound), tubeSideRange.upperBound)
        let rings = count + (samples.isClosed ? 1 : 0)
        let capped = caps && !samples.isClosed
        try checkCurveBudget(vertices: rings * (n + 1) + (capped ? 2 * (n + 1) : 0),
                             indices: 6 * n * (rings - 1) + (capped ? 6 * n : 0), budget: budget)

        let frames = try CurveFrames.parallelTransport(samples)
        var around: [(Double, Double)] = (0..<n).map { k in
            let angle = 2 * Double.pi * Double(k) / Double(n)
            return (sin(angle), cos(angle))
        }
        around.append(around[0])
        var positions: [Vec3] = [], normals: [Vec3] = [], uvs: [Vec2] = [], indices: [UInt32] = []
        for i in 0..<rings {
            let seam = i == count
            let f = frames[i]
            let v = (seam ? samples.length : samples.arcLengths[i]) / repeatSize
            for k in 0...n {
                let (sine, cosine) = around[k]
                let direction = (f.normal * cosine + f.binormal * sine).normalized
                positions.append(f.position + direction * radius); normals.append(direction)
                uvs.append(Vec2(Double(k) / Double(n), v))
            }
        }
        for i in 0..<(rings - 1) {
            for k in 0..<n {
                let a = UInt32(i * (n + 1) + k), b = a + 1, c = a + UInt32(n + 1), d = c + 1
                indices += [a, b, d, a, d, c]
            }
        }
        if capped {
            for end in [0, count - 1] {
                let f = frames[end]
                let outward = end == 0 ? -f.tangent : f.tangent
                let center = UInt32(positions.count)
                positions.append(f.position); normals.append(outward); uvs.append(Vec2(0.5, 0.5))
                for k in 0..<n {
                    let (sine, cosine) = around[k]
                    positions.append(f.position + (f.normal * cosine + f.binormal * sine).normalized * radius)
                    normals.append(outward); uvs.append(Vec2(0.5 + 0.5 * cosine, 0.5 + 0.5 * sine))
                }
                for k in 0..<n {
                    let p = center + 1 + UInt32(k), q = center + 1 + UInt32((k + 1) % n)
                    indices += end == 0 ? [center, q, p] : [center, p, q]
                }
            }
        }
        return Mesh(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }

    /// One mesh holding `meshes` in order (clarification Q5).
    ///
    /// Positions, normals and texture coordinates are concatenated in order and each part's indices are offset by
    /// the number of vertices before it. Nothing is welded across parts, so a merge of valid meshes that do not touch
    /// is valid and draws in one call.
    ///
    /// - Throws: `.invalidInput` for an empty list or a part whose normal or texture-coordinate count differs from
    ///   its position count; `.budget` when the summed counts exceed `budget`.
    public static func merged(_ meshes: [Mesh], budget: MeshBudget = .default) throws(MeshError) -> Mesh {
        guard !meshes.isEmpty else { throw .invalidInput("merge needs at least one mesh") }
        var vertices = 0, indexCount = 0
        for (k, part) in meshes.enumerated() {
            guard part.normals.count == part.positions.count, part.uvs.count == part.positions.count else {
                throw .invalidInput("mesh \(k) has attribute arrays of different lengths")
            }
            vertices += part.positions.count
            indexCount += part.indices.count
        }
        try checkCurveBudget(vertices: vertices, indices: indexCount, budget: budget)
        var result = Mesh(positions: [], normals: [], uvs: [], indices: [])
        result.positions.reserveCapacity(vertices); result.normals.reserveCapacity(vertices)
        result.uvs.reserveCapacity(vertices); result.indices.reserveCapacity(indexCount)
        for part in meshes {
            let base = UInt32(result.positions.count)
            result.positions += part.positions
            result.normals += part.normals
            result.uvs += part.uvs
            result.indices += part.indices.map { $0 + base }
        }
        return result
    }

    /// The repeat length used for v: `repeatLength`, or for a loop `L / max(1, round(L / repeatLength))`.
    private static func curveRepeat(_ samples: CurveSamples, _ repeatLength: Double) throws(MeshError) -> Double {
        guard repeatLength.isFinite, repeatLength > 0 else {
            throw .invalidInput("repeat length must be finite and positive")
        }
        guard samples.isClosed else { return repeatLength }
        let total = samples.length
        return total / max(1, (total / repeatLength).rounded())
    }

    /// Throws `.budget` when `vertices` or `indices` exceed `budget`.
    private static func checkCurveBudget(vertices: Int, indices: Int, budget: MeshBudget) throws(MeshError) {
        if vertices > budget.maxVertices || indices > budget.maxIndices {
            throw .budget(vertices: vertices, indices: indices, budget: budget)
        }
    }
}
