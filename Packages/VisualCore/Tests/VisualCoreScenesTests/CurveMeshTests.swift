// CurveMeshTests — feature 208 (R02-F08) T-R02F08-004 (FR-R02F08-004, FR-R02F08-005, FR-R02F08-007; SC-R02F08-003,
// SC-R02F08-004, SC-R02F08-005). Ribbon and tube texture v grows by 1 per repeat length within 1e-9 and meets across
// closed seams; per-sample widths are followed and bad widths refused; ribbons and tubes validate (open or closed as
// expected); a merge of 200 meshes sums counts, offsets indices and validates; budgets are refused; and the existing
// `Mesh.tube(path:…)` keeps its exact output (digests recorded on 2026-11-19 with MeshShapes.swift unchanged).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// Largest component difference of two vectors.
private func gap(_ a: Vec3, _ b: Vec3) -> Double { max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z)) }

/// Every triangle has area and faces the side its vertex normals point to (counter-clockwise from there).
private func facesAgree(_ m: Mesh) -> Bool {
    stride(from: 0, to: m.indices.count, by: 3).allSatisfy { k in
        let (i, j, l) = (Int(m.indices[k]), Int(m.indices[k + 1]), Int(m.indices[k + 2]))
        let face = (m.positions[j] - m.positions[i]).cross(m.positions[l] - m.positions[i])
        return face.length > 1e-14 && face.dot(m.normals[i] + m.normals[j] + m.normals[l]) > 0
    }
}

private func helixSamples() throws -> CurveSamples {
    try CurveSampler.sample(try CurveFixtures.helix(), tolerance: 1e-3)
}

private func trefoilSamples() throws -> CurveSamples {
    try CurveSampler.sample(try CurveFixtures.trefoil(), tolerance: 1e-3)
}

@Test func ribbonTextureGrowsOnePerRepeatLength() throws {
    let samples = try helixSamples()
    for repeatLength in [0.25, 1, 3.7] {
        let ribbon = try Mesh.ribbon(samples, width: .constant(0.1), repeatLength: repeatLength)
        #expect(ribbon.positions.count == 2 * samples.positions.count)
        #expect(ribbon.indices.count == 6 * (samples.positions.count - 1))
        for i in samples.positions.indices {
            let left = ribbon.uvs[2 * i], right = ribbon.uvs[2 * i + 1]
            #expect(left.x == 0 && right.x == 1 && left.y == right.y)
            #expect(abs(left.y * repeatLength - samples.arcLengths[i]) <= 1e-9)
            if i > 0 {
                let dv = left.y - ribbon.uvs[2 * i - 2].y
                #expect(abs(dv - (samples.arcLengths[i] - samples.arcLengths[i - 1]) / repeatLength) <= 1e-9)
            }
        }
    }
}

@Test func closedSeamsMeet() throws {
    let samples = try trefoilSamples()
    let count = samples.positions.count
    for repeatLength in [0.3, 1, 2.5] {
        let ribbon = try Mesh.ribbon(samples, width: .constant(0.05), repeatLength: repeatLength)
        #expect(ribbon.positions.count == 2 * (count + 1) && ribbon.indices.count == 6 * count)
        // A whole number of repeats fits the loop, so the seam v is an integer and the pattern meets.
        let seamV = ribbon.uvs[2 * count].y
        #expect(abs(seamV - seamV.rounded()) <= 1e-9 && seamV >= 1)
        let used = samples.length / seamV
        #expect(abs(used - repeatLength) <= 0.5 * used)
        for side in 0...1 {
            #expect(gap(ribbon.positions[2 * count + side], ribbon.positions[side]) <= 1e-9)
            #expect(gap(ribbon.normals[2 * count + side], ribbon.normals[side]) <= 1e-9)
        }
        let tube = try Mesh.tube(samples: samples, radius: 0.05, sides: 8, caps: true, repeatLength: repeatLength)
        #expect(tube.positions.count == 9 * (count + 1))   // a loop ignores caps
        for k in 0...8 {
            #expect(gap(tube.positions[9 * count + k], tube.positions[k]) <= 1e-9)
            #expect(abs(tube.uvs[9 * count + k].y - seamV) <= 1e-12 && tube.uvs[k].y == 0)
        }
    }
}

@Test func ribbonFollowsPerSampleWidth() throws {
    let samples = try helixSamples()
    let widths = samples.arcLengths.map { 0.05 + 0.1 * abs(sin($0)) }
    let ribbon = try Mesh.ribbon(samples, width: .perSample(widths))
    let frames = try CurveFrames.parallelTransport(samples)
    for i in samples.positions.indices {
        let left = ribbon.positions[2 * i], right = ribbon.positions[2 * i + 1]
        #expect(abs((right - left).length - widths[i]) <= 1e-12)
        #expect(gap((left + right) * 0.5, samples.positions[i]) <= 1e-12)
        #expect(gap((right - left).normalized, frames[i].binormal) <= 1e-9)
        #expect(ribbon.normals[2 * i] == frames[i].normal)
    }
}

@Test func badWidthsAndRepeatLengthsAreRefused() throws {
    let samples = try helixSamples()
    for w in [0, -0.1, Double.nan, Double.infinity] {
        #expect(throws: MeshError.self) { try Mesh.ribbon(samples, width: .constant(w)) }
    }
    var widths = Array(repeating: 0.1, count: samples.positions.count)
    #expect(throws: MeshError.self) { try Mesh.ribbon(samples, width: .perSample(Array(widths.dropLast()))) }
    widths[3] = 0
    #expect(throws: MeshError.self) { try Mesh.ribbon(samples, width: .perSample(widths)) }
    widths[3] = .nan
    #expect(throws: MeshError.self) { try Mesh.ribbon(samples, width: .perSample(widths)) }
    for r in [0, -1, Double.nan] {
        #expect(throws: MeshError.self) { try Mesh.ribbon(samples, width: .constant(0.1), repeatLength: r) }
        #expect(throws: MeshError.self) {
            try Mesh.tube(samples: samples, radius: 0.1, sides: 8, caps: false, repeatLength: r)
        }
    }
    for radius in [0, Double.infinity] {
        #expect(throws: MeshError.self) { try Mesh.tube(samples: samples, radius: radius, sides: 8, caps: false) }
    }
    #expect(throws: MeshError.self) {
        try Mesh.ribbon(samples, width: .constant(0.1), initialNormal: Vec3(.infinity, 0, 0))
    }
}

@Test func ribbonsAndTubesValidate() throws {
    let open = try helixSamples(), loop = try trefoilSamples()
    // One repeat over the whole length keeps v in 0…1, so the validator has nothing to report.
    let ribbon = try Mesh.ribbon(open, width: .constant(0.1), repeatLength: open.length)
    let report = ribbon.validate()
    #expect(report.isValid, "\(report)")
    #expect(!report.summary.isClosed && report.summary.boundaryEdges == 2 * (open.positions.count - 1) + 2)
    #expect(facesAgree(ribbon))
    // Required closed, an open ribbon reports nothing but its boundary.
    #expect(ribbon.validate(requireClosed: true).problems.allSatisfy { $0.kind == .boundaryEdge })
    let band = try Mesh.ribbon(loop, width: .constant(0.05), repeatLength: loop.length)
    let bandReport = band.validate()
    #expect(bandReport.isValid, "\(bandReport)")
    #expect(bandReport.summary.boundaryEdges == 2 * loop.positions.count)   // two long sides, the seam is joined
    #expect(facesAgree(band))
    // Tiled texture coordinates (v above 1) are the only other thing the validator reports.
    let tiled = try Mesh.ribbon(open, width: .constant(0.1), repeatLength: 0.5).validate()
    #expect(!tiled.problems.isEmpty && tiled.problems.allSatisfy { $0.kind == .uvOutOfRange })

    let capped = try Mesh.tube(samples: open, radius: 0.05, sides: 12, caps: true, repeatLength: open.length)
    let cappedReport = capped.validate(requireClosed: true)
    #expect(cappedReport.isValid, "\(cappedReport)")
    #expect((cappedReport.summary.volume ?? 0) > 0)
    #expect(facesAgree(capped))
    let ring = try Mesh.tube(samples: loop, radius: 0.05, sides: 12, caps: false, repeatLength: loop.length)
    let ringReport = ring.validate(requireClosed: true)
    #expect(ringReport.isValid, "\(ringReport)")
    #expect((ringReport.summary.volume ?? 0) > 0)
    let uncapped = try Mesh.tube(samples: open, radius: 0.05, sides: 12, caps: false, repeatLength: open.length)
    let uncappedReport = uncapped.validate()
    #expect(uncappedReport.isValid && uncappedReport.summary.boundaryEdges == 24, "\(uncappedReport)")
}

@Test func sampledTubeMatchesTheExistingTube() throws {
    let samples = try helixSamples()
    for (sides, caps) in [(8, false), (2, true), (300, false)] {
        let ours = try Mesh.tube(samples: samples, radius: 0.07, sides: sides, caps: caps, repeatLength: samples.length)
        let theirs = try Mesh.tube(path: samples.positions, radius: 0.07, sides: sides, caps: caps, closed: false)
        #expect(ours.positions.count == theirs.positions.count && ours.indices == theirs.indices)
        var worst = 0.0
        for i in ours.positions.indices {
            worst = max(worst, gap(ours.positions[i], theirs.positions[i]), gap(ours.normals[i], theirs.normals[i]),
                        abs(ours.uvs[i].x - theirs.uvs[i].x), abs(ours.uvs[i].y - theirs.uvs[i].y))
        }
        #expect(worst <= 1e-9, "sides \(sides): \(worst)")
    }
}

@Test func mergeOfTwoHundredMeshes() throws {
    var parts: [Mesh] = []
    for k in 0..<200 {
        let origin = Vec3(Double(k % 20) * 3, Double(k / 20) * 3, 0)
        let points = (0...8).map { j -> Vec3 in
            let a = Double(j) * 0.4 + Double(k) * 0.01
            return origin + Vec3(Double(j) * 0.25, 0.5 * sin(a), 0.2 * cos(a))
        }
        let samples = try CurveSampler.sample(try CatmullRomSpline(points: points, closed: false), tolerance: 1e-3)
        parts.append(k % 4 == 3
            ? try Mesh.tube(samples: samples, radius: 0.05, sides: 6, caps: true, repeatLength: samples.length)
            : try Mesh.ribbon(samples, width: .constant(0.1 + 0.001 * Double(k)), repeatLength: samples.length))
    }
    let merged = try Mesh.merged(parts)
    #expect(merged.positions.count == parts.reduce(0) { $0 + $1.positions.count })
    #expect(merged.indices.count == parts.reduce(0) { $0 + $1.indices.count })
    var base = 0, offset = 0
    for part in parts {
        #expect(Array(merged.positions[base..<(base + part.positions.count)]) == part.positions)
        #expect(Array(merged.uvs[base..<(base + part.uvs.count)]) == part.uvs)
        #expect(Array(merged.indices[offset..<(offset + part.indices.count)]) == part.indices.map { $0 + UInt32(base) })
        base += part.positions.count
        offset += part.indices.count
    }
    let report = merged.validate()
    #expect(report.isValid, "\(report)")
    #expect(try Mesh.merged(parts) == merged)
    #expect(try Mesh.merged([parts[0]]) == parts[0])
}

@Test func mergeRefusesEmptyListsMismatchedPartsAndTheBudget() throws {
    #expect(throws: MeshError.self) { try Mesh.merged([]) }
    var broken = Mesh.cube()
    broken.uvs.removeLast()
    #expect(throws: MeshError.self) { try Mesh.merged([Mesh.cube(), broken]) }
    let cube = Mesh.cube()
    let tight = MeshBudget(maxVertices: 2 * cube.positions.count, maxIndices: 2 * cube.indices.count)
    #expect(try Mesh.merged([cube, cube], budget: tight).positions.count == 2 * cube.positions.count)
    do {
        _ = try Mesh.merged([cube, cube, cube], budget: tight)
        Issue.record("expected a budget refusal")
    } catch {
        #expect(error == .budget(vertices: 3 * cube.positions.count, indices: 3 * cube.indices.count, budget: tight))
    }
}

@Test func ribbonAndTubeRefuseTheBudget() throws {
    let samples = try helixSamples()
    let n = samples.positions.count
    let exact = MeshBudget(maxVertices: 2 * n, maxIndices: 6 * (n - 1))
    #expect(try Mesh.ribbon(samples, width: .constant(0.1), budget: exact).positions.count == 2 * n)
    let short = MeshBudget(maxVertices: 2 * n - 1, maxIndices: 6 * (n - 1))
    #expect(throws: MeshError.budget(vertices: 2 * n, indices: 6 * (n - 1), budget: short)) {
        try Mesh.ribbon(samples, width: .constant(0.1), budget: short)
    }
    let tubeBudget = MeshBudget(maxVertices: 100, maxIndices: 100_000)
    #expect(throws: MeshError.self) {
        try Mesh.tube(samples: samples, radius: 0.1, sides: 8, caps: true, budget: tubeBudget)
    }
}

@Test func curveMeshesAreDeterministic() throws {
    let samples = try trefoilSamples()
    let ribbon = try Mesh.ribbon(samples, width: .constant(0.1))
    #expect(try Mesh.ribbon(samples, width: .constant(0.1)).digest == ribbon.digest)
    #expect(try Mesh.tube(samples: samples, radius: 0.1, sides: 8, caps: false).digest
            == Mesh.tube(samples: samples, radius: 0.1, sides: 8, caps: false).digest)
}

/// FR-R02F08-007: the existing tube keeps its exact output.
@Test func existingTubeKeepsItsOutput() throws {
    let path = (0...24).map { k -> Vec3 in
        let a = Double(k) * 0.5
        return Vec3(cos(a), sin(a), 0.1 * a)
    }
    let open = try Mesh.tube(path: path, radius: 0.1, sides: 8, caps: true, closed: false)
    let loop = try Mesh.tube(path: (0..<12).map { k in
        let a = 2 * Double.pi * Double(k) / 12
        return Vec3(cos(a), sin(a), 0.2 * sin(3 * a))
    }, radius: 0.2, sides: 6, caps: false, closed: true)
    #expect(open.digest == "94fcf8cfd39a1cbf9d0feaec7598d65dc16d38d8285f6afe8c1f02ba601b8f9a")
    #expect(loop.digest == "dc5b288c1156c4ce999bc064df056fbb7f3c74d4314719705f302a9be93bcdab")
}
