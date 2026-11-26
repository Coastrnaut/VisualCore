// MicroscopicAuroraSwimTests — feature 481 (R02-G19-01) T-R02G1901-003 (FR-R02G1901-003, 004, 005, 014;
// SC-R02G1901-003, 004; clarifications Q1 … Q4). The exact swim against an independent reference written from the
// spec's clarifications alone: the synchronous tick (neighbours within ρ, separation within σ with coincident swimmers
// pushed ±1 on x by index, alignment and cohesion means, the weights over 64, 16 and 256, the curl of each well about
// its cell centre, every division truncating toward zero, the acceleration and then the velocity clamped per axis,
// p ← p + v), the enclosure (rim inside), trail density over the ticks swum, lit cells, coverage in tenths of a percent
// rounded down, four-neighbour groups, coherence and the judge (per tick `exit` then `coherence`, after the swim
// `coverage` then `connectedness`). 500 seeded swims, each with its winning and its starting wells, agree on every
// position at every tick and on every report value; hand cases pin the rim, coincident swimmers, the threshold, the
// coverage and coherence requirements, a swim with no well, a reversed well and hand-made groups. Explicit types,
// plain loops.
import Foundation
import Testing
@testable import MicroscopicAuroraCore

/// An independent reference of the swim, written from clarifications Q1 … Q4 only (integers, no kernel logic).
private enum ReferenceSwim {
    /// The result of one reference swim.
    struct Result {
        /// The positions (x, y interleaved) of every tick swum, tick 0 first.
        var positions: [[Int]] = []
        /// The final velocities (x, y interleaved).
        var velocities: [Int] = []
        /// The ticks swum.
        var ticks: Int = 0
        /// The density of each of the 576 cells, row-major.
        var density: [Int] = []
        /// The row-major indices of the lit stencil cells, ascending.
        var lit: [Int] = []
        /// The coverage in tenths of a percent, rounded down.
        var coverage: Int = 0
        /// The number of four-neighbour groups of the lit stencil cells.
        var groups: Int = 0
        /// The smallest coherence (tick 0 included) and the first tick it was seen.
        var smallest: Int = 0
        var smallestTick: Int = 0
        /// The judge's failure, or nil for a win.
        var failure: MicroscopicAuroraFailure?
    }

    /// The enclosure test of clarification Q1: (x − 3072)² + (y − 3072)² ≤ (256R)².
    static func inside(_ x: Int, _ y: Int, radius: Int) -> Bool {
        let dx: Int = x - 3072
        let dy: Int = y - 3072
        let r: Int = 256 * radius
        return dx * dx + dy * dy <= r * r
    }

    /// `value` limited to −bound … bound.
    static func limit(_ value: Int, _ bound: Int) -> Int {
        if value > bound { return bound }
        if value < -bound { return -bound }
        return value
    }

    /// One synchronous tick of clarification Q2 over interleaved positions `p` and velocities `v`.
    static func tick(p: [Int], v: [Int], wells: [MicroscopicAuroraWell],
                     rules: MicroscopicAuroraSwarmRules) -> (p: [Int], v: [Int]) {
        let n: Int = p.count / 2
        let rhoUnits: Int = rules.neighbourRadius * 256
        let sigmaUnits: Int = rules.separationRadius * 256
        var ax: [Int] = Array(repeating: 0, count: n)
        var ay: [Int] = Array(repeating: 0, count: n)
        for i in 0..<n {
            let xi: Int = p[2 * i]
            let yi: Int = p[2 * i + 1]
            var neighbours: Int = 0
            var meanVX: Int = 0
            var meanVY: Int = 0
            var meanPX: Int = 0
            var meanPY: Int = 0
            var separationX: Int = 0
            var separationY: Int = 0
            for j in 0..<n {
                if j == i { continue }
                let ex: Int = xi - p[2 * j]
                let ey: Int = yi - p[2 * j + 1]
                let squared: Int = ex * ex + ey * ey
                if squared <= rhoUnits * rhoUnits {
                    neighbours += 1
                    meanVX += v[2 * j]
                    meanVY += v[2 * j + 1]
                    meanPX += p[2 * j]
                    meanPY += p[2 * j + 1]
                }
                if squared <= sigmaUnits * sigmaUnits {
                    if ex == 0 && ey == 0 {
                        // Same point: the lower index is pushed along +x, the higher along −x, by one unit.
                        separationX += (i < j) ? 1 : -1
                    } else {
                        separationX += ex
                        separationY += ey
                    }
                }
            }
            var alignmentX: Int = 0
            var alignmentY: Int = 0
            var cohesionX: Int = 0
            var cohesionY: Int = 0
            if neighbours > 0 {
                // Swift's `/` truncates toward zero, as the clarification requires.
                alignmentX = meanVX / neighbours - v[2 * i]
                alignmentY = meanVY / neighbours - v[2 * i + 1]
                cohesionX = meanPX / neighbours - xi
                cohesionY = meanPY / neighbours - yi
            }
            var totalX: Int = (rules.separationWeight * separationX) / 64
                + (rules.alignmentWeight * alignmentX) / 16 + (rules.cohesionWeight * cohesionX) / 256
            var totalY: Int = (rules.separationWeight * separationY) / 64
                + (rules.alignmentWeight * alignmentY) / 16 + (rules.cohesionWeight * cohesionY) / 256
            for well in wells {
                let centreX: Int = well.cell.column * 256 + 128
                let centreY: Int = well.cell.row * 256 + 128
                let dx: Int = xi - centreX
                let dy: Int = yi - centreY
                let sense: Int = well.sense == .counterclockwise ? 1 : -1
                let k: Int = sense * well.strength * 4096
                let d: Int = dx * dx + dy * dy + 65_536
                totalX += (k * (-dy)) / d
                totalY += (k * dx) / d
            }
            ax[i] = limit(totalX, rules.maxAcceleration)
            ay[i] = limit(totalY, rules.maxAcceleration)
        }
        var nextP: [Int] = p
        var nextV: [Int] = v
        for i in 0..<n {
            nextV[2 * i] = limit(v[2 * i] + ax[i], rules.maxSpeed)
            nextV[2 * i + 1] = limit(v[2 * i + 1] + ay[i], rules.maxSpeed)
            nextP[2 * i] = p[2 * i] + nextV[2 * i]
            nextP[2 * i + 1] = p[2 * i + 1] + nextV[2 * i + 1]
        }
        return (nextP, nextV)
    }

    /// The root of `a` in a union-find forest.
    static func root(_ parent: inout [Int], _ a: Int) -> Int {
        var r: Int = a
        while parent[r] != r { r = parent[r] }
        var c: Int = a
        while parent[c] != r {
            let next: Int = parent[c]
            parent[c] = r
            c = next
        }
        return r
    }

    /// The largest group of swimmers linked within κ cells (clarification Q4), by union-find.
    static func coherence(_ p: [Int], radius: Int) -> Int {
        let n: Int = p.count / 2
        let k: Int = radius * 256
        var parent: [Int] = Array(0..<n)
        for a in 0..<n {
            for b in (a + 1)..<max(a + 1, n) {
                let ex: Int = p[2 * a] - p[2 * b]
                let ey: Int = p[2 * a + 1] - p[2 * b + 1]
                if ex * ex + ey * ey <= k * k {
                    let ra: Int = root(&parent, a)
                    let rb: Int = root(&parent, b)
                    if ra != rb { parent[rb] = ra }
                }
            }
        }
        var sizes: [Int] = Array(repeating: 0, count: n)
        var best: Int = 0
        for a in 0..<n {
            let r: Int = root(&parent, a)
            sizes[r] += 1
            if sizes[r] > best { best = sizes[r] }
        }
        return best
    }

    /// For row-major cell indices `cells`: each cell's group root (by union-find over four-neighbour adjacency).
    static func groupRoots(_ cells: [Int]) -> [Int: Int] {
        var position: [Int: Int] = [:]
        for (k, c) in cells.enumerated() { position[c] = k }
        var parent: [Int] = Array(0..<cells.count)
        for (k, c) in cells.enumerated() {
            let column: Int = c % 24
            // Right and down neighbours suffice for an undirected union; columns must not wrap across rows.
            var others: [Int] = []
            if column < 23 { others.append(c + 1) }
            others.append(c + 24)
            for o in others {
                if let m = position[o] {
                    let ra: Int = root(&parent, k)
                    let rb: Int = root(&parent, m)
                    if ra != rb { parent[rb] = ra }
                }
            }
        }
        var roots: [Int: Int] = [:]
        for (k, c) in cells.enumerated() { roots[c] = root(&parent, k) }
        return roots
    }

    /// The number of four-neighbour groups of `cells`.
    static func groupCount(_ cells: [Int]) -> Int {
        let roots: [Int: Int] = groupRoots(cells)
        return Set(roots.values).count
    }

    /// The swim of `level` with `wells`, judged as clarification Q4 says.
    static func swim(_ level: MicroscopicAuroraLevel, wells: [MicroscopicAuroraWell]) -> Result {
        var result = Result()
        var p: [Int] = []
        var v: [Int] = []
        for s in level.swimmers {
            p.append(s.position.x)
            p.append(s.position.y)
            v.append(s.velocity.x)
            v.append(s.velocity.y)
        }
        let n: Int = level.swimmers.count
        result.positions.append(p)
        result.density = Array(repeating: 0, count: 576)
        result.smallest = coherence(p, radius: level.rules.coherenceRadius)
        result.smallestTick = 0
        var t: Int = 1
        while t <= level.length {
            let moved: (p: [Int], v: [Int]) = tick(p: p, v: v, wells: wells, rules: level.rules)
            p = moved.p
            v = moved.v
            result.ticks = t
            result.positions.append(p)
            var outside: Int = -1
            for i in 0..<n where outside < 0 && !inside(p[2 * i], p[2 * i + 1], radius: level.radius) {
                outside = i
            }
            if outside >= 0 {
                result.failure = .exit(swimmer: outside, tick: t)
                break
            }
            for i in 0..<n {
                let column: Int = p[2 * i] / 256
                let row: Int = p[2 * i + 1] / 256
                result.density[row * 24 + column] += 1
            }
            let c: Int = coherence(p, radius: level.rules.coherenceRadius)
            if c < result.smallest {
                result.smallest = c
                result.smallestTick = t
            }
            if c < level.coherence {
                result.failure = .coherence(tick: t, group: c)
                break
            }
            t += 1
        }
        result.velocities = v
        var stencil: [Int] = []
        for cell in level.stencil { stencil.append(cell.row * 24 + cell.column) }
        stencil.sort()
        for c in stencil where result.density[c] >= level.threshold { result.lit.append(c) }
        result.coverage = (result.lit.count * 1000) / stencil.count
        let roots: [Int: Int] = groupRoots(result.lit)
        result.groups = Set(roots.values).count
        if result.failure == nil {
            if result.coverage < level.coverage {
                let product: Int = level.coverage * stencil.count
                let needed: Int = product / 1000 + (product % 1000 == 0 ? 0 : 1)
                result.failure = .coverage(lit: result.lit.count, needed: needed)
            } else if result.groups > 1 {
                let firstRoot: Int = roots[result.lit[0]] ?? -1
                for c in result.lit where roots[c] != firstRoot {
                    result.failure = .connectedness(cell: MicroscopicAuroraCell(row: c / 24, column: c % 24))
                    break
                }
            }
        }
        return result
    }
}

@Suite struct MicroscopicAuroraSwimTests {
    /// The 500 seeded fixtures, built once (about 3.7 s).
    static let fixtures: [MicroscopicAuroraFixture] = MicroscopicAuroraFixture.all(count: 500)

    /// Swarm rules with every weight zero (straight lines unless a well acts).
    static let still = MicroscopicAuroraSwarmRules(neighbourRadius: 2, separationRadius: 1, coherenceRadius: 2,
                                                   separationWeight: 0, alignmentWeight: 0, cohesionWeight: 0,
                                                   maxAcceleration: 16, maxSpeed: 48)

    /// A swimmer at (x, y) moving by (vx, vy).
    static func swimmer(_ x: Int, _ y: Int, _ vx: Int = 0, _ vy: Int = 0) -> MicroscopicAuroraSwimmer {
        MicroscopicAuroraSwimmer(position: MicroscopicAuroraPoint(x: x, y: y),
                                 velocity: MicroscopicAuroraPoint(x: vx, y: vy))
    }

    /// The cells of row-major `indices`.
    static func cells(_ indices: [Int]) -> [MicroscopicAuroraCell] {
        var result: [MicroscopicAuroraCell] = []
        for i in indices { result.append(MicroscopicAuroraCell(row: i / 24, column: i % 24)) }
        return result
    }

    /// Compares the kernel's swim of `level` with `wells` to the reference; returns the kernel's failure code.
    static func compare(_ level: MicroscopicAuroraLevel, wells: [MicroscopicAuroraWell], label: String) -> String {
        let kernel: (report: MicroscopicAuroraReport, positions: [[MicroscopicAuroraPoint]]) =
            MicroscopicAuroraDish.swim(level, wells: wells, keepPositions: true)
        let reference: ReferenceSwim.Result = ReferenceSwim.swim(level, wells: wells)
        let report: MicroscopicAuroraReport = kernel.report
        #expect(kernel.positions.count == reference.positions.count, "\(label) ticks of positions")
        let ticks: Int = min(kernel.positions.count, reference.positions.count)
        var firstMismatch: Int = -1
        for t in 0..<ticks where firstMismatch < 0 {
            var flat: [Int] = []
            for point in kernel.positions[t] {
                flat.append(point.x)
                flat.append(point.y)
            }
            if flat != reference.positions[t] { firstMismatch = t }
        }
        #expect(firstMismatch < 0, "\(label) positions differ first at tick \(firstMismatch)")
        var finalVelocities: [Int] = []
        for s in report.finalSwimmers {
            finalVelocities.append(s.velocity.x)
            finalVelocities.append(s.velocity.y)
        }
        #expect(finalVelocities == reference.velocities, "\(label) final velocities")
        #expect(report.ticks == reference.ticks, "\(label) ticks")
        #expect(report.density == reference.density, "\(label) density")
        var lit: [Int] = []
        for cell in report.litStencil { lit.append(cell.index) }
        #expect(lit == reference.lit, "\(label) lit stencil")
        #expect(report.coverage == reference.coverage, "\(label) coverage")
        #expect(report.groups == reference.groups, "\(label) groups")
        #expect(report.smallestCoherence == reference.smallest, "\(label) smallest coherence")
        #expect(report.smallestCoherenceTick == reference.smallestTick, "\(label) smallest coherence tick")
        #expect(report.failure == reference.failure, "\(label) failure")
        #expect(report.wins == (reference.failure == nil), "\(label) outcome")
        return report.failure?.code ?? "won"
    }

    @Test func kernelMatchesTheReferenceOn500SeededSwims() {
        let fixtures: [MicroscopicAuroraFixture] = Self.fixtures
        #expect(fixtures.count == 500)
        var codes: [String: Int] = [:]
        for (k, fixture) in fixtures.enumerated() {
            var winning: [MicroscopicAuroraWell] = []
            for well in fixture.winning { if let well { winning.append(well) } }
            let won: String = Self.compare(fixture.level, wells: winning, label: "fixture \(k) winning")
            #expect(won == "won", "fixture \(k) winning wells win")
            let start: String = Self.compare(fixture.level, wells: fixture.level.placedWells,
                                             label: "fixture \(k) start")
            #expect(start != "won", "fixture \(k) starting wells do not win")
            codes[start, default: 0] += 1
        }
        // The starting wells exercise every judge rule (seed 2 481: 22 exit, 32 coherence, 440 coverage,
        // 6 connectedness).
        let all: [String] = ["exit", "coherence", "coverage", "connectedness"]
        for code in all { #expect((codes[code] ?? 0) > 0, "starting failure codes \(codes)") }
    }

    @Test func rimIsInsideAndOneUnitBeyondIsNot() {
        for radius in MicroscopicAuroraLevel.radii {
            let r: Int = radius * 256
            let onRim: [MicroscopicAuroraPoint] = [
                MicroscopicAuroraPoint(x: 3072 + r, y: 3072), MicroscopicAuroraPoint(x: 3072 - r, y: 3072),
                MicroscopicAuroraPoint(x: 3072, y: 3072 + r), MicroscopicAuroraPoint(x: 3072, y: 3072 - r),
            ]
            let beyond: [MicroscopicAuroraPoint] = [
                MicroscopicAuroraPoint(x: 3072 + r + 1, y: 3072), MicroscopicAuroraPoint(x: 3072 - r - 1, y: 3072),
                MicroscopicAuroraPoint(x: 3072, y: 3072 + r + 1), MicroscopicAuroraPoint(x: 3072, y: 3072 - r - 1),
            ]
            for point in onRim { #expect(MicroscopicAuroraDish.isInside(point, radius: radius)) }
            for point in beyond { #expect(!MicroscopicAuroraDish.isInside(point, radius: radius)) }
        }
        // A diagonal rim point: radius 10 is 2560 = 5 · 512, so (1536, 2048) from the centre lies on it.
        #expect(MicroscopicAuroraDish.isInside(MicroscopicAuroraPoint(x: 3072 + 1536, y: 3072 + 2048), radius: 10))
        #expect(!MicroscopicAuroraDish.isInside(MicroscopicAuroraPoint(x: 3072 + 1537, y: 3072 + 2048), radius: 10))
    }

    @Test func swimmerOnTheRimStaysAndOneBeyondExits() throws {
        // Radius 6 (1536 units). Swimmer 0 reaches the rim exactly at tick 1, passes it at tick 2; swimmer 2 also
        // passes the rim at tick 2, so the lowest index (0) is named.
        let swimmers: [MicroscopicAuroraSwimmer] = [
            Self.swimmer(3072 + 1536 - 10, 3072, 10, 0), Self.swimmer(3072, 3072),
            Self.swimmer(3072 - 1536 + 15, 3072, -10, 0), Self.swimmer(3072, 3072 + 1),
        ]
        let level: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.probe(
            radius: 6, length: 120, rules: Self.still, swimmers: swimmers, stencil: Self.cells([275, 276, 299, 300]),
            threshold: 1, coverage: 500, coherence: 2, wells: [nil, nil, nil])
        let swim: (report: MicroscopicAuroraReport, positions: [[MicroscopicAuroraPoint]]) =
            MicroscopicAuroraDish.swim(level, wells: [], keepPositions: true)
        #expect(swim.positions[1][0] == MicroscopicAuroraPoint(x: 3072 + 1536, y: 3072))
        #expect(swim.report.failure == .exit(swimmer: 0, tick: 2))
        #expect(swim.report.ticks == 2)
        _ = Self.compare(level, wells: [], label: "rim")
    }

    @Test func coincidentSwimmersSeparateAlongXByIndex() {
        // Nine swimmers on one point at rest: swimmer i's separation is (8 − i) − i on x, 0 on y; with wₛ = 8 the
        // acceleration is 8·(8 − 2i)/64 truncated toward zero: +1 for swimmer 0, −1 for swimmer 8, 0 between.
        let rules = MicroscopicAuroraSwarmRules(neighbourRadius: 2, separationRadius: 1, coherenceRadius: 2,
                                                separationWeight: 8, alignmentWeight: 8, cohesionWeight: 8,
                                                maxAcceleration: 16, maxSpeed: 48)
        var swimmers: [MicroscopicAuroraSwimmer] = []
        for _ in 0..<9 { swimmers.append(Self.swimmer(3000, 3100)) }
        let next: [MicroscopicAuroraSwimmer] = MicroscopicAuroraDish.step(swimmers, wells: [], rules: rules)
        for i in 0..<9 {
            let expected: Int = (8 * (8 - 2 * i)) / 64
            #expect(next[i].velocity == MicroscopicAuroraPoint(x: expected, y: 0), "swimmer \(i)")
            #expect(next[i].position == MicroscopicAuroraPoint(x: 3000 + expected, y: 3100), "swimmer \(i)")
        }
        #expect(next[0].velocity.x == 1)
        #expect(next[8].velocity.x == -1)
        // Two coincident swimmers: ±1 each, which a weight of 64 would show; here wₛ·1/64 truncates to 0.
        let pair: [MicroscopicAuroraSwimmer] = [Self.swimmer(3000, 3100), Self.swimmer(3000, 3100)]
        let movedPair: [MicroscopicAuroraSwimmer] = MicroscopicAuroraDish.step(pair, wells: [], rules: rules)
        #expect(movedPair[0].velocity == MicroscopicAuroraPoint(x: 0, y: 0))
        // The reference agrees on the nine.
        var p: [Int] = []
        var v: [Int] = []
        for s in swimmers {
            p.append(s.position.x)
            p.append(s.position.y)
            v.append(0)
            v.append(0)
        }
        let reference: (p: [Int], v: [Int]) = ReferenceSwim.tick(p: p, v: v, wells: [], rules: rules)
        for i in 0..<9 { #expect(next[i].velocity.x == reference.v[2 * i]) }
    }

    @Test func densityEqualToTheThresholdIsLitAndOneBelowIsNot() throws {
        // A fixture's winning swim; a stencil cell whose density d lies in 1 … 63 is lit at threshold d, not at d + 1.
        var checked: Int = 0
        for fixture in Self.fixtures where checked < 5 {
            let level: MicroscopicAuroraLevel = fixture.level
            var winning: [MicroscopicAuroraWell] = []
            for well in fixture.winning { if let well { winning.append(well) } }
            let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(level, wells: winning)
            var chosen: MicroscopicAuroraCell?
            for cell in level.stencil where chosen == nil {
                let d: Int = report.density[cell.index]
                if d >= 1 && d <= 63 { chosen = cell }
            }
            guard let cell = chosen else { continue }
            let d: Int = report.density[cell.index]
            for threshold in [d, d + 1] {
                let probe: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.probe(
                    radius: level.radius, length: level.length, rules: level.rules, swimmers: level.swimmers,
                    stencil: level.stencil, threshold: threshold, coverage: 500, coherence: level.coherence,
                    wells: fixture.winning)
                let lit: [MicroscopicAuroraCell] = MicroscopicAuroraDish.report(probe, wells: winning).litStencil
                #expect(lit.contains(cell) == (threshold == d), "density \(d) threshold \(threshold)")
            }
            checked += 1
        }
        #expect(checked == 5)
    }

    @Test func coverageOneCellEitherSideOfTheRequirement() throws {
        // A winning swim lights its whole stencil of L cells; one unlit usable cell is added, so coverage is
        // c = ⌊1000·L/(L + 1)⌋. Requiring c wins; requiring c + 1 needs L + 1 cells and fails `coverage`.
        var checked: Int = 0
        for fixture in Self.fixtures where checked < 5 && fixture.level.stencil.count < 120 {
            let level: MicroscopicAuroraLevel = fixture.level
            var winning: [MicroscopicAuroraWell] = []
            for well in fixture.winning { if let well { winning.append(well) } }
            let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(level, wells: winning)
            var extra: MicroscopicAuroraCell?
            for index in 0..<576 where extra == nil {
                let cell = MicroscopicAuroraCell(row: index / 24, column: index % 24)
                if report.density[index] == 0 && MicroscopicAuroraLevel.isUsable(cell, radius: level.radius) {
                    extra = cell
                }
            }
            guard let cell = extra else { continue }
            let count: Int = level.stencil.count
            let stencil: [MicroscopicAuroraCell] = level.stencil + [cell]
            let c: Int = (1000 * count) / (count + 1)
            let pass: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.probe(
                radius: level.radius, length: level.length, rules: level.rules, swimmers: level.swimmers,
                stencil: stencil, threshold: level.threshold, coverage: c, coherence: level.coherence,
                wells: fixture.winning)
            let passed: MicroscopicAuroraReport = MicroscopicAuroraDish.report(pass, wells: winning)
            #expect(passed.coverage == c)
            #expect(passed.wins, "fixture coverage \(c) of \(count + 1)")
            let fail: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.probe(
                radius: level.radius, length: level.length, rules: level.rules, swimmers: level.swimmers,
                stencil: stencil, threshold: level.threshold, coverage: c + 1, coherence: level.coherence,
                wells: fixture.winning)
            let failed: MicroscopicAuroraReport = MicroscopicAuroraDish.report(fail, wells: winning)
            #expect(failed.failure == .coverage(lit: count, needed: count + 1))
            #expect(MicroscopicAuroraDish.neededCells(stencil: count + 1, required: c + 1) == count + 1)
            #expect(MicroscopicAuroraDish.neededCells(stencil: count + 1, required: c) == count)
            _ = Self.compare(pass, wells: winning, label: "coverage pass")
            _ = Self.compare(fail, wells: winning, label: "coverage fail")
            checked += 1
        }
        #expect(checked == 5)
    }

    @Test func coherenceOneSwimmerEitherSideOfTheRequirement() throws {
        // κ = 2 cells (512). Swimmer 3 starts 507 to the right of swimmer 0 and drifts +10 per tick, so after tick 1
        // the largest linked group is 3. Requiring 4 fails `coherence` at tick 1 with group 3; requiring 3 wins.
        let swimmers: [MicroscopicAuroraSwimmer] = [
            Self.swimmer(3072, 3072), Self.swimmer(3071, 3072), Self.swimmer(3072, 3071),
            Self.swimmer(3072 + 507, 3072, 10, 0),
        ]
        let stencil: [MicroscopicAuroraCell] = [
            MicroscopicAuroraCell(row: 11, column: 11), MicroscopicAuroraCell(row: 11, column: 12),
            MicroscopicAuroraCell(row: 12, column: 11), MicroscopicAuroraCell(row: 12, column: 12),
        ]
        let strict: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.probe(
            radius: 11, length: 120, rules: Self.still, swimmers: swimmers, stencil: stencil, threshold: 1,
            coverage: 500, coherence: 4, wells: [nil, nil, nil])
        let strictReport: MicroscopicAuroraReport = MicroscopicAuroraDish.report(strict, wells: [])
        #expect(strictReport.failure == .coherence(tick: 1, group: 3))
        #expect(strictReport.smallestCoherence == 3)
        #expect(strictReport.smallestCoherenceTick == 1)
        let loose: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.probe(
            radius: 11, length: 120, rules: Self.still, swimmers: swimmers, stencil: stencil, threshold: 1,
            coverage: 500, coherence: 3, wells: [nil, nil, nil])
        let looseReport: MicroscopicAuroraReport = MicroscopicAuroraDish.report(loose, wells: [])
        #expect(looseReport.wins)
        #expect(looseReport.coverage == 750)
        #expect(looseReport.smallestCoherence == 3)
        #expect(looseReport.smallestCoherenceTick == 1)
        _ = Self.compare(strict, wells: [], label: "coherence strict")
        _ = Self.compare(loose, wells: [], label: "coherence loose")
    }

    @Test func swimWithNoWell() throws {
        // With every weight zero and no well, each swimmer moves in a straight line: p(t) = p(0) + t·v.
        let swimmers: [MicroscopicAuroraSwimmer] = [
            Self.swimmer(3072, 3072, 1, 2), Self.swimmer(3100, 3000, -2, 1),
            Self.swimmer(3000, 3150, 0, -1), Self.swimmer(3050, 3050, 2, 2),
        ]
        let level: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.probe(
            radius: 11, length: 120, rules: Self.still, swimmers: swimmers,
            stencil: Self.cells([275, 276, 299, 300]), threshold: 1, coverage: 500, coherence: 2,
            wells: [nil, nil, nil])
        let swim: (report: MicroscopicAuroraReport, positions: [[MicroscopicAuroraPoint]]) =
            MicroscopicAuroraDish.swim(level, wells: [], keepPositions: true)
        #expect(swim.positions.count == 121)
        for t in 0...120 {
            for (i, s) in swimmers.enumerated() {
                let expected = MicroscopicAuroraPoint(x: s.position.x + t * s.velocity.x,
                                                      y: s.position.y + t * s.velocity.y)
                #expect(swim.positions[t][i] == expected, "tick \(t) swimmer \(i)")
            }
        }
        var total: Int = 0
        for d in swim.report.density { total += d }
        #expect(total == 4 * 120)
        _ = Self.compare(level, wells: [], label: "no well")
        // Fixtures swum with no well also agree with the reference.
        for k in 0..<50 { _ = Self.compare(Self.fixtures[k].level, wells: [], label: "fixture \(k) no well") }
    }

    @Test func reversingAWellsSenseMirrorsTheTurn() {
        // A single swimmer at rest one cell right of the well's centre (3200, 3200): the curl is
        // sense·s·4096·(0, 256)/(65536 + 65536) = sense·8·s on y.
        let cell = MicroscopicAuroraCell(row: 12, column: 12)
        let ccw = MicroscopicAuroraWell(cell: cell, strength: 1, sense: .counterclockwise)
        let cw = MicroscopicAuroraWell(cell: cell, strength: 1, sense: .clockwise)
        let right: [MicroscopicAuroraSwimmer] = [Self.swimmer(3200 + 256, 3200)]
        #expect(MicroscopicAuroraDish.step(right, wells: [ccw], rules: Self.still)[0].velocity
            == MicroscopicAuroraPoint(x: 0, y: 8))
        #expect(MicroscopicAuroraDish.step(right, wells: [cw], rules: Self.still)[0].velocity
            == MicroscopicAuroraPoint(x: 0, y: -8))
        // Everywhere around the well, the clockwise acceleration is the exact negation of the counterclockwise one.
        var offsets: Int = 0
        for ox in stride(from: -900, through: 900, by: 97) {
            for oy in stride(from: -900, through: 900, by: 89) {
                for strength in MicroscopicAuroraWell.strengths {
                    let a = MicroscopicAuroraWell(cell: cell, strength: strength, sense: .counterclockwise)
                    let b = MicroscopicAuroraWell(cell: cell, strength: strength, sense: .clockwise)
                    let one: [MicroscopicAuroraSwimmer] = [Self.swimmer(3200 + ox, 3200 + oy)]
                    let va: MicroscopicAuroraPoint = MicroscopicAuroraDish.step(one, wells: [a], rules: Self.still)[0]
                        .velocity
                    let vb: MicroscopicAuroraPoint = MicroscopicAuroraDish.step(one, wells: [b], rules: Self.still)[0]
                        .velocity
                    #expect(va.x == -vb.x && va.y == -vb.y, "offset (\(ox), \(oy)) strength \(strength)")
                    let reference: (p: [Int], v: [Int]) = ReferenceSwim.tick(
                        p: [3200 + ox, 3200 + oy], v: [0, 0], wells: [a], rules: Self.still)
                    #expect(va.x == reference.v[0] && va.y == reference.v[1])
                    offsets += 1
                }
            }
        }
        #expect(offsets > 1000)
    }

    @Test func groupsOfHandMadeCellSets() {
        let cases: [(indices: [Int], groups: Int)] = [
            ([], 0),
            ([0], 1),
            ([0, 25], 2),              // diagonal neighbours are separate groups
            ([0, 1, 25], 1),           // an L joins through the shared edge
            ([23, 24], 2),             // the end of one row and the start of the next do not touch
            ([100, 102, 125, 148], 4), // cells touching only at corners
            ([100, 101, 102, 124, 126, 148, 149, 150], 1), // a ring
            ([300, 301, 324, 325, 330], 2),
        ]
        for (k, item) in cases.enumerated() {
            let cells: [MicroscopicAuroraCell] = Self.cells(item.indices)
            #expect(MicroscopicAuroraDish.groups(cells) == item.groups, "case \(k)")
            #expect(ReferenceSwim.groupCount(item.indices) == item.groups, "reference case \(k)")
        }
        let groups: [[MicroscopicAuroraCell]] = MicroscopicAuroraDish.groupsOf(Self.cells([330, 300, 325, 301, 324]))
        #expect(groups == [Self.cells([300, 301, 324, 325]), Self.cells([330])])
    }
}
