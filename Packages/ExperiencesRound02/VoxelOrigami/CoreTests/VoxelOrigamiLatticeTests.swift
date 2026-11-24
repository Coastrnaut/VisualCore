// VoxelOrigamiLatticeTests — feature 441 (R02-G15-01) T-R02G1501-003 (FR-R02G1501-002, 003, 004, 014; SC-R02G1501-003,
// 004; clarifications Q2, Q3, Q4). The exact lattice against independent references: on 500 seeded levels (the
// fixtures) and random clear-turn walks drawn from seed 2_441, every pose equals a recomputation that rotates each
// subtree's cell list directly about its hinge line (never calling `VoxelOrigamiLattice.pose`), every collision
// decision equals a set intersection of the moving end cells with the still cells, every sweep decision equals a fine
// sampling of the quarter arc (1 000 steps, an axis-aligned unit cube centred on the arc point overlapping a still unit
// cube) wherever the sampling is unambiguous, and canonical forms and covered counts equal a brute-force enumeration of
// the allowed rotations and translations. Hand cases: an L of three cubes turning about its middle (the hinge cube
// never blocks, a cube diagonal to the arc does), cells inside and clear of a swept path (the parent on the axis
// included), a straight chain whose turn is idle, a target matched under `any` but not under `upright`, and the 24
// rotations (distinct, closed, orthogonal, determinant 1). Explicit types and plain loops keep the type checker fast on
// CI.
//
// Why the independent pose applies hinges from the highest index down: the kernel's pose is the product of the local
// transforms along the path root → k, N(1) R(1) N(2) R(2) … N(k) R(k) (N a rest translation, R a hinge's quarter turn
// in its parent's frame). With A(j) = N(1) … N(j) the rest placement of cube j this equals W(1) W(2) … W(k) A(k), where
// W(j) = A(j) R(j) A(j)⁻¹ is the quarter turn about hinge j's REST line. Applied to a rest cell, W(k) acts first: the
// deepest hinge first, each about its rest line. Taking hinges in decreasing index order does exactly that, and when
// hinge j is taken neither cube j nor its parent has moved yet (only a lower index, an ancestor, can move them), so its
// line through the current positions is its rest line. The root-outward order (increasing index, each about its line in
// the then-current positions) is the same product written as conjugates, W'(j) = W(anc) W(j) W(anc)⁻¹, and is checked
// as a second, independent route.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiLatticeTests {
    // MARK: - Independent integer geometry

    static func dot(_ a: VoxelOrigamiVector, _ b: VoxelOrigamiVector) -> Int { a.x * b.x + a.y * b.y + a.z * b.z }

    static func cross(_ a: VoxelOrigamiVector, _ b: VoxelOrigamiVector) -> VoxelOrigamiVector {
        VoxelOrigamiVector(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    static func scaled(_ a: VoxelOrigamiVector, _ k: Int) -> VoxelOrigamiVector {
        VoxelOrigamiVector(a.x * k, a.y * k, a.z * k)
    }

    /// `v` turned `turns` quarter turns counter-clockwise (right-hand rule) about the unit direction `axis`, one
    /// quarter at a time by Rodrigues' formula at 90 degrees: v ↦ a × v + (a · v) a.
    static func quarterTurned(_ v: VoxelOrigamiVector, about axis: VoxelOrigamiVector,
                              turns: Int) -> VoxelOrigamiVector {
        let count: Int = ((turns % 4) + 4) % 4
        var result: VoxelOrigamiVector = v
        for _ in 0..<count { result = cross(axis, result) + scaled(axis, dot(axis, result)) }
        return result
    }

    /// The children of every cube.
    static func children(_ cubes: [VoxelOrigamiCube]) -> [[Int]] {
        var result: [[Int]] = Array(repeating: [], count: cubes.count)
        for index in cubes.indices {
            if let parent = cubes[index].parent { result[parent].append(index) }
        }
        return result
    }

    /// Cube `hinge`'s strict descendants by a depth-first walk of the children lists.
    static func subtree(_ kids: [[Int]], of hinge: Int) -> [Int] {
        var result: [Int] = []
        var stack: [Int] = kids[hinge]
        while let next = stack.popLast() {
            result.append(next)
            for child in kids[next] { stack.append(child) }
        }
        return result.sorted()
    }

    /// The rest cells: every orientation is the identity, so x(i) = x(p) + d(i) in world terms.
    static func restCells(_ cubes: [VoxelOrigamiCube]) -> [VoxelOrigamiVector] {
        var cells: [VoxelOrigamiVector] = []
        for cube in cubes {
            if let parent = cube.parent {
                cells.append(cells[parent] + cube.direction)
            } else {
                cells.append(.zero)
            }
        }
        return cells
    }

    /// An independent pose: the rest cells and identity frames (three basis vectors per cube), then for every hinge
    /// with a non-zero turn the subtree's cells and the frames of the hinge cube and its subtree turned about the
    /// hinge line in the then-current positions. `deepestFirst` takes hinges in decreasing index order, else in
    /// increasing order (both are correct, see the header).
    static func recomputed(_ cubes: [VoxelOrigamiCube], turns: [Int],
                           deepestFirst: Bool) -> (cells: [VoxelOrigamiVector], frames: [[VoxelOrigamiVector]]) {
        var cells: [VoxelOrigamiVector] = restCells(cubes)
        let basis: [VoxelOrigamiVector] = [VoxelOrigamiVector(1, 0, 0), VoxelOrigamiVector(0, 1, 0),
                                           VoxelOrigamiVector(0, 0, 1)]
        var frames: [[VoxelOrigamiVector]] = Array(repeating: basis, count: cubes.count)
        let kids: [[Int]] = children(cubes)
        var order: [Int] = Array(1..<cubes.count)
        if deepestFirst { order.reverse() }
        for hinge in order {
            guard let parent = cubes[hinge].parent else { continue }
            let q: Int = ((turns[hinge] % 4) + 4) % 4
            if q == 0 { continue }
            let axis: VoxelOrigamiVector = cells[hinge] - cells[parent]
            let centre: VoxelOrigamiVector = cells[hinge]
            let inside: [Int] = subtree(kids, of: hinge)
            for k in inside { cells[k] = centre + quarterTurned(cells[k] - centre, about: axis, turns: q) }
            for k in [hinge] + inside {
                var frame: [VoxelOrigamiVector] = []
                for e in frames[k] { frame.append(quarterTurned(e, about: axis, turns: q)) }
                frames[k] = frame
            }
        }
        return (cells, frames)
    }

    // MARK: - Independent sweep sampling

    /// The cosines and sines of the 1 001 sample angles 0 … π/2.
    static let samples: [(c: Double, s: Double)] = {
        var table: [(c: Double, s: Double)] = []
        for t in 0...1000 {
            let phi: Double = Double(t) / 1000.0 * Double.pi / 2.0
            table.append((cos(phi), sin(phi)))
        }
        return table
    }()

    /// The smallest Chebyshev distance between the still cube's centre and a moving cube's centre sampled on its
    /// quarter arc (offset `r` from the hinge, direction `step` about the unit `axis`): an axis-aligned unit cube
    /// overlaps the still one exactly when this is below 1. Stops early once it is clearly below.
    static func sampledSeparation(r: VoxelOrigamiVector, still s: VoxelOrigamiVector, axis a: VoxelOrigamiVector,
                                  step: Int) -> Double {
        let axr: VoxelOrigamiVector = cross(a, r)
        let ar: Int = dot(a, r)
        var best: Double = Double.infinity
        for sample in samples {
            let sn: Double = sample.s * Double(step)
            let k: Double = Double(ar) * (1.0 - sample.c)
            let px: Double = Double(r.x) * sample.c + Double(axr.x) * sn + Double(a.x) * k
            let py: Double = Double(r.y) * sample.c + Double(axr.y) * sn + Double(a.y) * k
            let pz: Double = Double(r.z) * sample.c + Double(axr.z) * sn + Double(a.z) * k
            let d: Double = max(abs(px - Double(s.x)), max(abs(py - Double(s.y)), abs(pz - Double(s.z))))
            if d < best { best = d }
            if best < 0.5 { break }
        }
        return best
    }

    /// A sampled pair decision: true (overlap), false (clear) or nil (within 0.02 of touching).
    static func sampledBlocks(_ separation: Double) -> Bool? {
        if separation < 0.98 { return true }
        if separation > 1.02 { return false }
        return nil
    }

    /// Tallies of the sweep comparison (per moving–still pair in one plane).
    struct SweepTally {
        var agree: Int = 0
        var ambiguous: Int = 0
        var kernelClearSampledBlocked: [String] = []
        var kernelBlockedSampledClear: [String] = []
    }

    /// Compares one turn against the references: swinging set, collision (set intersection) and, when no collision,
    /// every in-plane moving–still pair's sweep decision against the sampling. The still cubes are every cube outside
    /// the turning body (the hinge cube and its whole subtree; its cubes on the axis spin in place). Returns whether
    /// the turn is clear per the kernel.
    static func compareTurn(_ cubes: [VoxelOrigamiCube], turns: [Int], hinge: Int, step: Int,
                            tally: inout SweepTally) -> Bool {
        let independent = recomputed(cubes, turns: turns, deepestFirst: true)
        let cells: [VoxelOrigamiVector] = independent.cells
        guard let parent = cubes[hinge].parent else { return false }
        let axis: VoxelOrigamiVector = cells[hinge] - cells[parent]
        let centre: VoxelOrigamiVector = cells[hinge]
        let kids: [[Int]] = children(cubes)
        var moving: [Int] = []
        let inside: [Int] = subtree(kids, of: hinge)
        for k in inside where cross(cells[k] - centre, axis) != .zero { moving.append(k) }
        let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(cubes, turns: turns)
        #expect(VoxelOrigamiLattice.swinging(cubes, pose: pose, hinge: hinge) == moving)
        if moving.isEmpty { return false }
        var still: [Int] = []
        for k in cubes.indices where k != hinge && !inside.contains(k) { still.append(k) }
        // Collision: the moving end cells against the still cells.
        var stillCells: Set<VoxelOrigamiVector> = []
        for k in still { stillCells.insert(cells[k]) }
        var firstCollision: Int? = nil
        for k in moving {
            let end: VoxelOrigamiVector = centre + quarterTurned(cells[k] - centre, about: axis, turns: step)
            if stillCells.contains(end) {
                firstCollision = k
                break
            }
        }
        let result: VoxelOrigamiFailure? = VoxelOrigamiLattice.check(cubes, turns: turns, hinge: hinge, step: step)
        if let k = firstCollision {
            let end: VoxelOrigamiVector = centre + quarterTurned(cells[k] - centre, about: axis, turns: step)
            if case .collision(let h, let m, _, let cell) = result {
                #expect(h == hinge && m == k && cell == end)
            } else {
                Issue.record("expected a collision of cube \(k) at \(end), got \(String(describing: result))")
            }
            return false
        }
        if case .collision = result { Issue.record("collision reported, none in the set intersection") }
        // Sweep: the kernel's pair rule against the sampling, pair by pair.
        var firstBand: (moving: Int, still: Int)? = nil
        for k in moving {
            let r: VoxelOrigamiVector = cells[k] - centre
            let end: VoxelOrigamiVector = centre + quarterTurned(r, about: axis, turns: step)
            for other in still {
                let kernel: Bool = VoxelOrigamiLattice.inBand(still: cells[other], start: cells[k], end: end,
                                                              axisPoint: centre, axis: axis, step: step)
                if kernel && firstBand == nil { firstBand = (k, other) }
                let s: VoxelOrigamiVector = cells[other] - centre
                // Another plane: the axial gap stays a whole cell, so a moving cube only ever touches.
                if dot(s, axis) != dot(r, axis) {
                    #expect(!kernel)
                    continue
                }
                let separation: Double = sampledSeparation(r: r, still: s, axis: axis, step: step)
                guard let sampled = sampledBlocks(separation) else {
                    tally.ambiguous += 1
                    continue
                }
                if sampled == kernel {
                    tally.agree += 1
                } else {
                    let text: String = "r=\(r) still=\(s) axis=\(axis) step=\(step) minChebyshev="
                        + String(format: "%.3f", separation)
                    if kernel {
                        tally.kernelBlockedSampledClear.append(text)
                    } else {
                        tally.kernelClearSampledBlocked.append(text)
                    }
                }
            }
        }
        if let band = firstBand {
            if case .sweep(let h, let m, let o, let cell) = result {
                #expect(h == hinge && m == band.moving && o == band.still && cell == cells[band.still])
            } else {
                let got: String = String(describing: result)
                Issue.record("expected a sweep of cube \(band.moving) by \(band.still), got \(got)")
            }
            return false
        }
        #expect(result == nil)
        return true
    }

    // MARK: - Brute force shape references

    /// The canonical form by brute force: every group rotation, every translation within the bounding range (the
    /// corner shift plus 0 … 2 more along each axis) that keeps every coordinate ≥ 0, the smallest sorted list kept.
    static func bruteCanonical(_ cells: [VoxelOrigamiVector], group: [VoxelOrigamiRotation]) -> [VoxelOrigamiVector] {
        var best: [VoxelOrigamiVector]? = nil
        for rotation in group {
            var rotated: [VoxelOrigamiVector] = []
            for cell in cells { rotated.append(rotation.applied(to: cell)) }
            var lowX: Int = Int.max
            var lowY: Int = Int.max
            var lowZ: Int = Int.max
            for cell in rotated {
                lowX = min(lowX, cell.x)
                lowY = min(lowY, cell.y)
                lowZ = min(lowZ, cell.z)
            }
            for dx in 0...2 {
                for dy in 0...2 {
                    for dz in 0...2 {
                        let shift = VoxelOrigamiVector(dx - lowX, dy - lowY, dz - lowZ)
                        var moved: [VoxelOrigamiVector] = []
                        var nonNegative: Bool = true
                        for cell in rotated {
                            let m: VoxelOrigamiVector = cell + shift
                            if m.x < 0 || m.y < 0 || m.z < 0 { nonNegative = false }
                            moved.append(m)
                        }
                        guard nonNegative else { continue }
                        moved.sort()
                        if let current = best {
                            if moved.lexicographicallyPrecedes(current) { best = moved }
                        } else {
                            best = moved
                        }
                    }
                }
            }
        }
        return best ?? []
    }

    /// The covered count by brute force: every group rotation and every translation in the box that can bring the
    /// rotated target's bounding box onto the occupied cells' bounding box, counted on a dense occupancy grid.
    static func bruteCovered(target: [VoxelOrigamiVector], occupied: [VoxelOrigamiVector],
                             group: [VoxelOrigamiRotation]) -> Int {
        var lo: [Int] = [Int.max, Int.max, Int.max]
        var hi: [Int] = [Int.min, Int.min, Int.min]
        for cell in occupied {
            let c: [Int] = [cell.x, cell.y, cell.z]
            for axis in 0..<3 {
                lo[axis] = min(lo[axis], c[axis])
                hi[axis] = max(hi[axis], c[axis])
            }
        }
        let size: [Int] = [hi[0] - lo[0] + 1, hi[1] - lo[1] + 1, hi[2] - lo[2] + 1]
        var grid: [Bool] = Array(repeating: false, count: size[0] * size[1] * size[2])
        for cell in occupied {
            grid[((cell.x - lo[0]) * size[1] + (cell.y - lo[1])) * size[2] + (cell.z - lo[2])] = true
        }
        var best: Int = 0
        for rotation in group {
            var rotated: [VoxelOrigamiVector] = []
            var tlo: [Int] = [Int.max, Int.max, Int.max]
            var thi: [Int] = [Int.min, Int.min, Int.min]
            for cell in target {
                let r: VoxelOrigamiVector = rotation.applied(to: cell)
                rotated.append(r)
                let c: [Int] = [r.x, r.y, r.z]
                for axis in 0..<3 {
                    tlo[axis] = min(tlo[axis], c[axis])
                    thi[axis] = max(thi[axis], c[axis])
                }
            }
            for tx in (lo[0] - thi[0])...(hi[0] - tlo[0]) {
                for ty in (lo[1] - thi[1])...(hi[1] - tlo[1]) {
                    for tz in (lo[2] - thi[2])...(hi[2] - tlo[2]) {
                        var count: Int = 0
                        for r in rotated {
                            let gx: Int = r.x + tx - lo[0]
                            let gy: Int = r.y + ty - lo[1]
                            let gz: Int = r.z + tz - lo[2]
                            if gx < 0 || gy < 0 || gz < 0 { continue }
                            if gx >= size[0] || gy >= size[1] || gz >= size[2] { continue }
                            if grid[(gx * size[1] + gy) * size[2] + gz] { count += 1 }
                        }
                        if count > best { best = count }
                    }
                }
            }
        }
        return best
    }

    // MARK: - Seeded properties

    static let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 500)

    @Test func everyPoseEqualsAnIndependentSubtreeRecomputation() {
        var random = SeededRandom(seed: 2_441)
        var poses: Int = 0
        for fixture in Self.fixtures {
            let cubes: [VoxelOrigamiCube] = fixture.level.cubes
            var states: [[Int]] = [fixture.level.startTurns, fixture.solution, Array(repeating: 0, count: cubes.count)]
            // Arbitrary quarter turns (collision-free or not, the pose rule is the same) and a clear-turn walk.
            var arbitrary: [Int] = [0]
            for _ in 1..<cubes.count { arbitrary.append(random.int(0...3)) }
            states.append(arbitrary)
            var turns: [Int] = fixture.level.startTurns
            for _ in 0..<8 {
                let hinge: Int = random.int(1...(cubes.count - 1))
                let step: Int = random.int(0...1) == 0 ? -1 : 1
                if let next = VoxelOrigamiFixture.apply(.turn(hinge, step), cubes: cubes, turns: turns) {
                    turns = next
                    states.append(turns)
                }
            }
            for state in states {
                let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(cubes, turns: state)
                let deep = Self.recomputed(cubes, turns: state, deepestFirst: true)
                let outward = Self.recomputed(cubes, turns: state, deepestFirst: false)
                #expect(pose.cells == deep.cells)
                #expect(outward.cells == deep.cells)
                for k in cubes.indices {
                    let o: VoxelOrigamiRotation = pose.orientations[k]
                    #expect(o.applied(to: VoxelOrigamiVector(1, 0, 0)) == deep.frames[k][0])
                    #expect(o.applied(to: VoxelOrigamiVector(0, 1, 0)) == deep.frames[k][1])
                    #expect(o.applied(to: VoxelOrigamiVector(0, 0, 1)) == deep.frames[k][2])
                    #expect(outward.frames[k] == deep.frames[k])
                    // Every hinge's two cubes stay face to face (clarification Q2).
                    if let parent = cubes[k].parent {
                        #expect((pose.cells[k] - pose.cells[parent]).isUnit)
                    }
                }
                poses += 1
            }
        }
        #expect(poses >= 3_000)
    }

    @Test func collisionsAndSweepsEqualSetIntersectionAndArcSampling() {
        var random = SeededRandom(seed: 2_441)
        var tally = SweepTally()
        var checked: Int = 0
        var collisions: Int = 0
        var clear: Int = 0
        for fixture in Self.fixtures {
            let cubes: [VoxelOrigamiCube] = fixture.level.cubes
            var turns: [Int] = fixture.level.startTurns
            for _ in 0..<6 {
                let hinge: Int = random.int(1...(cubes.count - 1))
                let step: Int = random.int(0...1) == 0 ? -1 : 1
                let ok: Bool = Self.compareTurn(cubes, turns: turns, hinge: hinge, step: step, tally: &tally)
                let result: VoxelOrigamiFailure? = VoxelOrigamiLattice.check(cubes, turns: turns, hinge: hinge,
                                                                             step: step)
                if case .collision = result { collisions += 1 }
                checked += 1
                if ok {
                    clear += 1
                    turns = VoxelOrigamiLattice.turned(turns, hinge: hinge, step: step)
                }
            }
        }
        let total: Int = tally.agree + tally.kernelBlockedSampledClear.count + tally.kernelClearSampledBlocked.count
        print("VoxelOrigamiLatticeTests sweep: turns \(checked), collisions \(collisions), clear \(clear), "
              + "pairs agree \(tally.agree), ambiguous \(tally.ambiguous), kernel blocked / sampled clear "
              + "\(tally.kernelBlockedSampledClear.count), kernel clear / sampled blocked "
              + "\(tally.kernelClearSampledBlocked.count) of \(total)")
        for text in tally.kernelClearSampledBlocked.prefix(10) { print("  kernel clear, sampled blocked: \(text)") }
        for text in tally.kernelBlockedSampledClear.prefix(10) { print("  kernel blocked, sampled clear: \(text)") }
        #expect(checked == 3_000)
        #expect(collisions > 0)
        #expect(clear > 0)
        #expect(tally.agree > 0)
        // Full agreement in every unambiguous case, both ways.
        #expect(tally.kernelBlockedSampledClear.isEmpty)
        #expect(tally.kernelClearSampledBlocked.isEmpty)
    }

    @Test func canonicalFormsAndCoveredCountsEqualBruteForce() {
        var random = SeededRandom(seed: 2_441)
        for fixture in Self.fixtures {
            let level: VoxelOrigamiLevel = fixture.level
            let group: [VoxelOrigamiRotation] = level.orientations.group
            let occupied: [VoxelOrigamiVector] = level.pose(turns: level.startTurns).occupied
            let canonical: [VoxelOrigamiVector] = VoxelOrigamiLattice.canonical(occupied, group: group)
            #expect(canonical == Self.bruteCanonical(occupied, group: group))
            #expect(level.targetCanonical == Self.bruteCanonical(level.target, group: group))
            let covered = VoxelOrigamiLattice.covered(target: level.target, occupied: occupied, group: group)
            #expect(covered.count == Self.bruteCovered(target: level.target, occupied: occupied, group: group))
            // The reported alignment really covers that many cells.
            let rotation: VoxelOrigamiRotation = group[covered.rotation]
            let occupiedSet: Set<VoxelOrigamiVector> = Set(occupied)
            var hits: Int = 0
            for cell in level.target where occupiedSet.contains(rotation.applied(to: cell) + covered.translation) {
                hits += 1
            }
            #expect(hits == covered.count)
            // At the solution the target is covered whole and matched.
            let solved: [VoxelOrigamiVector] = level.pose(turns: fixture.solution).occupied
            #expect(VoxelOrigamiLattice.covered(target: level.target, occupied: solved, group: group).count
                == level.cubes.count)
            #expect(VoxelOrigamiLattice.canonical(solved, group: group) == level.targetCanonical)
            // Invariance under any group rotation and translation of the input.
            let g: VoxelOrigamiRotation = group[random.int(0...(group.count - 1))]
            let shift = VoxelOrigamiVector(random.int(-5...5), random.int(-5...5), random.int(-5...5))
            var moved: [VoxelOrigamiVector] = []
            for cell in occupied { moved.append(g.applied(to: cell) + shift) }
            #expect(VoxelOrigamiLattice.canonical(moved, group: group) == canonical)
            #expect(VoxelOrigamiLattice.canonicalHash(moved, group: group)
                == VoxelOrigamiLattice.canonicalHash(occupied, group: group))
        }
    }

    // MARK: - Hand cases

    /// An L of three cubes (0, 1 at +x, 2 above 1) with a still cube 5 at (1, 1, 1), diagonal to cube 2's arc for a
    /// positive turn of hinge 1, reached through cubes 3 (0, 1, 0) and 4 (0, 1, 1).
    static let lCubes: [VoxelOrigamiCube] = [
        .root,
        VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0)),
        VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, 1, 0)),
        VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(0, 1, 0)),
        VoxelOrigamiCube(parent: 3, direction: VoxelOrigamiVector(0, 0, 1)),
        VoxelOrigamiCube(parent: 4, direction: VoxelOrigamiVector(1, 0, 0)),
    ]

    @Test func anLTurningAboutItsMiddle() {
        let bare: [VoxelOrigamiCube] = Array(Self.lCubes.prefix(3))
        let rest: [Int] = [0, 0, 0]
        let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(bare, turns: rest)
        #expect(pose.cells == [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0), VoxelOrigamiVector(1, 1, 0)])
        #expect(VoxelOrigamiLattice.swinging(bare, pose: pose, hinge: 1) == [2])
        // The hinge cube is part of the turning body (it spins in place) and never blocks, either way.
        for step in [-1, 1] { #expect(VoxelOrigamiLattice.check(bare, turns: rest, hinge: 1, step: step) == nil) }
        // Nor does a descendant on the axis: cube 3 orbits cube 2 (on the axis, in the body) at ρ = 1 in layer x = 2.
        let onAxis: [VoxelOrigamiCube] = [
            .root,
            VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0)),
            VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(1, 0, 0)),
            VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(0, 1, 0)),
            VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, 1, 0)),
        ]
        let onAxisPose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(onAxis, turns: [0, 0, 0, 0, 0])
        #expect(VoxelOrigamiLattice.swinging(onAxis, pose: onAxisPose, hinge: 1) == [3, 4])
        for step in [-1, 1] {
            #expect(VoxelOrigamiLattice.check(onAxis, turns: [0, 0, 0, 0, 0], hinge: 1, step: step) == nil)
        }
        #expect(VoxelOrigamiLattice.pose(bare, turns: [0, 1, 0]).cells[2] == VoxelOrigamiVector(1, 0, 1))
        // A cube diagonal to the arc blocks the positive turn and not the negative one.
        let full: [Int] = [0, 0, 0, 0, 0, 0]
        let cells: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(Self.lCubes, turns: full).cells
        #expect(cells[5] == VoxelOrigamiVector(1, 1, 1))
        #expect(VoxelOrigamiLattice.check(Self.lCubes, turns: full, hinge: 1, step: 1)
            == .sweep(hinge: 1, moving: 2, still: 5, cell: VoxelOrigamiVector(1, 1, 1)))
        #expect(VoxelOrigamiLattice.check(Self.lCubes, turns: full, hinge: 1, step: -1) == nil)
        // The sampling agrees: the diagonal cube is overlapped mid-arc (0.707 from the arc point).
        let separation: Double = Self.sampledSeparation(r: VoxelOrigamiVector(0, 1, 0),
                                                        still: VoxelOrigamiVector(0, 1, 1),
                                                        axis: VoxelOrigamiVector(1, 0, 0), step: 1)
        #expect(separation < 0.75)
        // A collision when the end cell is taken: cube 5 moved to (1, 0, 1) by turning hinge 5 is not possible here, so
        // a fresh tree puts a still cube at (1, 0, 1) through (0, 0, 1).
        let blocked: [VoxelOrigamiCube] = Array(Self.lCubes.prefix(3)) + [
            VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(0, 0, 1)),
            VoxelOrigamiCube(parent: 3, direction: VoxelOrigamiVector(1, 0, 0)),
        ]
        #expect(VoxelOrigamiLattice.check(blocked, turns: [0, 0, 0, 0, 0], hinge: 1, step: 1)
            == .collision(hinge: 1, moving: 2, still: 4, cell: VoxelOrigamiVector(1, 0, 1)))
    }

    @Test func cellsInsideAndClearOfASweptBand() {
        // A cube at (2, 0, 0) turning a quarter about +z through the origin to (0, 2, 0): ρ = 2. A still cube blocks
        // when the open arc enters the open square of half-side 1 around it.
        let start = VoxelOrigamiVector(2, 0, 0)
        let end = VoxelOrigamiVector(0, 2, 0)
        let z = VoxelOrigamiVector(0, 0, 1)
        let inside: [VoxelOrigamiVector] = [VoxelOrigamiVector(2, 2, 0), VoxelOrigamiVector(1, 1, 0),
                                            VoxelOrigamiVector(2, 1, 0), VoxelOrigamiVector(1, 2, 0),
                                            VoxelOrigamiVector(1, 0, 0), VoxelOrigamiVector(0, 1, 0)]
        let clear: [VoxelOrigamiVector] = [VoxelOrigamiVector(3, 3, 0), VoxelOrigamiVector(2, 2, 1),
                                           VoxelOrigamiVector(3, 0, 0), VoxelOrigamiVector(0, 3, 0),
                                           VoxelOrigamiVector(-1, 1, 0), VoxelOrigamiVector(1, -1, 0),
                                           VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(3, 1, 0),
                                           VoxelOrigamiVector(1, 3, 0)]
        for cell in inside {
            #expect(VoxelOrigamiLattice.inBand(still: cell, start: start, end: end, axisPoint: .zero, axis: z, step: 1))
            #expect(Self.sampledSeparation(r: start, still: cell, axis: z, step: 1) < 0.98)
        }
        for cell in clear {
            #expect(!VoxelOrigamiLattice.inBand(still: cell, start: start, end: end, axisPoint: .zero, axis: z,
                                                step: 1))
            #expect(Self.sampledSeparation(r: start, still: cell, axis: z, step: 1) >= 1.0 - 1e-9)
        }
        // The same arc run backwards (−1 from the end) has the same band; about −z the step flips.
        for cell in inside {
            #expect(VoxelOrigamiLattice.inBand(still: cell, start: end, end: start, axisPoint: .zero, axis: z,
                                               step: -1))
            #expect(VoxelOrigamiLattice.inBand(still: cell, start: start, end: end, axisPoint: .zero,
                                               axis: VoxelOrigamiVector(0, 0, -1), step: -1))
        }
        // (2, 0, 0) → (0, 2, 0) clips a still cube at (1, 0, 0), ρ − 1 from the axis, just after the start.
        #expect(VoxelOrigamiLattice.inBand(still: VoxelOrigamiVector(1, 0, 0), start: start, end: end,
                                           axisPoint: .zero, axis: z, step: 1))
        // (1, 1, 0) → (−1, 1, 0) about +z (ρ² = 2) peaks at (0, √2, 0), 0.586 below a still cube at (0, 2, 0): blocked.
        #expect(VoxelOrigamiLattice.inBand(still: VoxelOrigamiVector(0, 2, 0), start: VoxelOrigamiVector(1, 1, 0),
                                           end: VoxelOrigamiVector(-1, 1, 0), axisPoint: .zero, axis: z, step: 1))
        #expect(Self.sampledSeparation(r: VoxelOrigamiVector(1, 1, 0), still: VoxelOrigamiVector(0, 2, 0), axis: z,
                                       step: 1) < 0.6)
        // One cell clear of that path: (0, 3, 0) is a whole cell above the peak's square, (2, 1, 0) beside the start.
        for cell in [VoxelOrigamiVector(0, 3, 0), VoxelOrigamiVector(2, 1, 0)] {
            #expect(!VoxelOrigamiLattice.inBand(still: cell, start: VoxelOrigamiVector(1, 1, 0),
                                                end: VoxelOrigamiVector(-1, 1, 0), axisPoint: .zero, axis: z, step: 1))
            #expect(Self.sampledSeparation(r: VoxelOrigamiVector(1, 1, 0), still: cell, axis: z, step: 1) >= 1.0 - 1e-9)
        }
        // The parent on the axis blocks a ρ = 1 orbit in its layer: cube 3 wrapped back beside cube 0 sweeps through
        // its corners (sampled 0.707 mid-arc) when hinge 1 turns.
        let wrapped: [VoxelOrigamiCube] = [
            .root,
            VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0)),
            VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, 1, 0)),
            VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(-1, 0, 0)),
        ]
        let wrappedCells: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(wrapped, turns: [0, 0, 0, 0]).cells
        #expect(wrappedCells[3] == VoxelOrigamiVector(0, 1, 0))
        for step in [-1, 1] {
            #expect(VoxelOrigamiLattice.check(wrapped, turns: [0, 0, 0, 0], hinge: 1, step: step)
                == .sweep(hinge: 1, moving: 3, still: 0, cell: .zero))
            #expect(Self.sampledSeparation(r: VoxelOrigamiVector(-1, 1, 0), still: VoxelOrigamiVector(-1, 0, 0),
                                           axis: VoxelOrigamiVector(1, 0, 0), step: step) < 0.75)
        }
        // The other way round (2, 0) → (0, −2) sweeps the fourth quadrant instead.
        #expect(!VoxelOrigamiLattice.inBand(still: VoxelOrigamiVector(1, 1, 0), start: start,
                                            end: VoxelOrigamiVector(0, -2, 0), axisPoint: .zero, axis: z, step: -1))
        #expect(VoxelOrigamiLattice.inBand(still: VoxelOrigamiVector(1, -1, 0), start: start,
                                           end: VoxelOrigamiVector(0, -2, 0), axisPoint: .zero, axis: z, step: -1))
    }

    @Test func aStraightChainTurnIsIdle() {
        var chain: [VoxelOrigamiCube] = [.root]
        for index in 1..<5 { chain.append(VoxelOrigamiCube(parent: index - 1, direction: VoxelOrigamiVector(1, 0, 0))) }
        let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(chain, turns: [0, 0, 0, 0, 0])
        for hinge in 1..<5 { #expect(VoxelOrigamiLattice.swinging(chain, pose: pose, hinge: hinge).isEmpty) }
        // Twisting the chain changes orientations only, never cells.
        let twisted: VoxelOrigamiPose = VoxelOrigamiLattice.pose(chain, turns: [0, 1, 2, 3, 1])
        #expect(twisted.cells == pose.cells)
        #expect(twisted.orientations != pose.orientations)
        #expect(VoxelOrigamiFixture.apply(.turn(2, 1), cubes: chain, turns: [0, 0, 0, 0, 0]) == nil)
    }

    @Test func aTargetMatchedUnderAnyButNotUpright() {
        let shape: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0),
                                           VoxelOrigamiVector(2, 0, 0), VoxelOrigamiVector(2, 1, 0)]
        // Turned a quarter about +x: (x, y, z) → (x, −z, y), the foot now along +z, then shifted.
        var target: [VoxelOrigamiVector] = []
        for cell in shape {
            target.append(Self.quarterTurned(cell, about: VoxelOrigamiVector(1, 0, 0), turns: 1)
                + VoxelOrigamiVector(4, -2, 7))
        }
        let any: [VoxelOrigamiRotation] = VoxelOrigamiOrientations.any.group
        let upright: [VoxelOrigamiRotation] = VoxelOrigamiOrientations.upright.group
        let fixed: [VoxelOrigamiRotation] = VoxelOrigamiOrientations.fixed.group
        #expect(VoxelOrigamiLattice.canonical(shape, group: any) == VoxelOrigamiLattice.canonical(target, group: any))
        #expect(VoxelOrigamiLattice.canonical(shape, group: upright)
            != VoxelOrigamiLattice.canonical(target, group: upright))
        #expect(VoxelOrigamiLattice.canonical(shape, group: fixed)
            != VoxelOrigamiLattice.canonical(target, group: fixed))
        #expect(VoxelOrigamiLattice.covered(target: target, occupied: shape, group: any).count == 4)
        #expect(VoxelOrigamiLattice.covered(target: target, occupied: shape, group: upright).count == 3)
        #expect(Self.bruteCovered(target: target, occupied: shape, group: upright) == 3)
        // A turn about +y is matched under `upright` too.
        var spun: [VoxelOrigamiVector] = []
        for cell in shape { spun.append(Self.quarterTurned(cell, about: VoxelOrigamiVector(0, 1, 0), turns: 3)) }
        #expect(VoxelOrigamiLattice.canonical(spun, group: upright)
            == VoxelOrigamiLattice.canonical(shape, group: upright))
        // A mirror image is never matched.
        var mirror: [VoxelOrigamiVector] = []
        let chiral: [VoxelOrigamiVector] = shape + [VoxelOrigamiVector(2, 1, 1)]
        for cell in chiral { mirror.append(VoxelOrigamiVector(-cell.x, cell.y, cell.z)) }
        #expect(VoxelOrigamiLattice.canonical(chiral, group: any) != VoxelOrigamiLattice.canonical(mirror, group: any))
    }

    @Test func theTwentyFourRotationsAreProperAndOrthogonal() {
        let all: [VoxelOrigamiRotation] = VoxelOrigamiRotation.all
        #expect(all.count == 24)
        #expect(Set(all).count == 24)
        #expect(Set(VoxelOrigamiOrientations.any.group) == Set(all))
        for r in all {
            let m: [Int] = r.m
            for i in 0..<3 {
                for j in 0..<3 {
                    var sum: Int = 0
                    for k in 0..<3 { sum += m[i * 3 + k] * m[j * 3 + k] }
                    #expect(sum == (i == j ? 1 : 0))
                }
            }
            let det: Int = m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6])
                + m[2] * (m[3] * m[7] - m[4] * m[6])
            #expect(det == 1)
            for s in all { #expect(all.contains(r * s)) }
        }
        // Each quarter turn equals the Rodrigues reference on every unit vector, about every axis, for every count.
        for axis in VoxelOrigamiVector.units {
            for turns in -4...4 {
                let q: VoxelOrigamiRotation = .quarter(about: axis, turns: turns)
                for v in VoxelOrigamiVector.units {
                    #expect(q.applied(to: v) == Self.quarterTurned(v, about: axis, turns: turns))
                }
            }
        }
    }
}
