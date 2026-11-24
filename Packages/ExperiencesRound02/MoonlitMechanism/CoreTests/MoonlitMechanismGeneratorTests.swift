// MoonlitMechanismGeneratorTests — feature 432 (R02-G14-02) T-R02G1402-004 (FR-R02G1402-001, 003, 005; SC-R02G1402-001,
// 003, 004; clarifications Q1, Q3, Q5). Host checks of the constructive level generator: the manifest (100 entries in
// order, 20 per band, budgets within the band's archived values, distinct seeds); the five band profiles of
// clarification Q1 and the clamp of out-of-range bands; the level ids, the tooth list, the compass and the candidate
// bound; candidate and generation determinism; the drawing order of the generator's header re-implemented independently
// here and compared field by field with `candidate` on (entry, index) pairs of every band, discarded draws included;
// every candidate value within its band, and the solution property (the drawn solution set-up wins and the start is
// that solution moved by the scramble's net vector, which a plan of at most that norm undoes); the filters of
// `generate` on all 100 entries in groups of 20 (the start never wins, a minimal plan in the band's range and at most
// budget − 1, `skipped` equal to the first qualifying candidate found by walking the candidates here, a winning
// witness through the play); difficulty metrics equal to an independent recount; the refusal `.generation(number)` when
// no candidate can qualify; and the catalog digest's determinism and order sensitivity. Explicit types, plain loops,
// short runs.
import Testing
import VisualCoreSimulation
@testable import MoonlitMechanismCore

@Suite("MoonlitMechanismGenerator")
struct MoonlitMechanismGeneratorTests {
    /// The manifest numbers sampled for the independent re-draw and the band values: four per band.
    static let sampledNumbers: [Int] = [1, 3, 13, 20, 21, 28, 35, 40, 41, 49, 52, 60, 61, 66, 73, 80, 81, 88, 94, 100]

    /// The candidate indices re-drawn per sampled entry.
    static let sampledIndices: Int = 12

    /// The archived moves budgets by band (index band − 1).
    static let budgetRanges: [ClosedRange<Int>] = [8...11, 10...13, 12...15, 14...17, 16...19]

    /// The generated levels of band 1 (manifest numbers 1 … 20), cached per process.
    static let band1: [MoonlitMechanismGenerated] = generateBand(1)
    /// The generated levels of band 2 (manifest numbers 21 … 40), cached per process.
    static let band2: [MoonlitMechanismGenerated] = generateBand(2)
    /// The generated levels of band 3 (manifest numbers 41 … 60), cached per process.
    static let band3: [MoonlitMechanismGenerated] = generateBand(3)
    /// The generated levels of band 4 (manifest numbers 61 … 80), cached per process.
    static let band4: [MoonlitMechanismGenerated] = generateBand(4)
    /// The generated levels of band 5 (manifest numbers 81 … 100), cached per process.
    static let band5: [MoonlitMechanismGenerated] = generateBand(5)

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> MoonlitMechanismManifestEntry {
        MoonlitMechanismManifest.entries[number - 1]
    }

    /// The certified levels of the 20 entries of `band` (a refused entry is left out, which the band tests catch).
    static func generateBand(_ band: Int) -> [MoonlitMechanismGenerated] {
        var result: [MoonlitMechanismGenerated] = []
        for number in ((band - 1) * 20 + 1)...(band * 20) {
            if let generated = try? MoonlitMechanismGenerator.generate(entry(number)) { result.append(generated) }
        }
        return result
    }

    /// A candidate re-drawn independently of the generator: the level values plus the solution and the scramble's net
    /// vector.
    struct Drawn {
        let width: Int
        let rows: Int
        let lampHeights: Int
        let gears: [MoonlitMechanismGear]
        let solution: [Int]
        let solutionHeight: Int
        let frames: [MoonlitMechanismKeyFrame]
        let forbidden: [Int]
        let startPhases: [Int]
        let startHeight: Int
        let scramble: Int
        let netTurns: Int
        let netLamp: Int
        let netReseats: [Int]
    }

    /// The direction (+1 or −1) of every gear from its parent chain.
    static func directions(_ parents: [Int?]) -> [Int] {
        var result: [Int] = []
        for gear in parents.indices {
            var steps: Int = 0
            var current: Int = gear
            while let parent = parents[current] {
                steps += 1
                current = parent
            }
            result.append(steps % 2 == 0 ? 1 : -1)
        }
        return result
    }

    /// `value` modulo `modulus`, in 0 ..< modulus.
    static func modulo(_ value: Int, _ modulus: Int) -> Int {
        ((value % modulus) + modulus) % modulus
    }

    /// The greatest common divisor.
    static func divisor(_ a: Int, _ b: Int) -> Int {
        var x: Int = a
        var y: Int = b
        while y != 0 {
            let r: Int = x % y
            x = y
            y = r
        }
        return x
    }

    /// The cells cast by the gears (centres, depths, blades, slots) at `phases` with the lamp at `height`.
    static func castCells(_ gears: [MoonlitMechanismGear], phases: [Int], height: Int, width: Int,
                          rows: Int) -> [Int] {
        var on: Set<Int> = []
        for gear in gears.indices {
            let value: MoonlitMechanismGear = gears[gear]
            for bit in 0..<value.teeth where value.blades[bit] {
                let slot: Int = modulo(bit + phases[gear], value.teeth)
                for offset in value.slots[slot] {
                    let column: Int = value.centre.column + offset.column
                    let row: Int = value.centre.row + offset.row + height * value.depth
                    if column >= 0, column < width, row >= 0, row < rows { on.insert(row * width + column) }
                }
            }
        }
        return on.sorted()
    }

    /// Candidate `index` of `entry` drawn independently in the order of the generator's header; nil where the draw
    /// discards it (an empty key-frame cast or no scramble action).
    static func redraw(_ entry: MoonlitMechanismManifestEntry, index: Int) -> Drawn? {
        let gearRanges: [ClosedRange<Int>] = [2...3, 3...3, 3...4, 4...4, 4...5]
        let lampRanges: [ClosedRange<Int>] = [2...3, 3...3, 3...4, 4...4, 4...5]
        let frameRanges: [ClosedRange<Int>] = [2...2, 2...3, 3...3, 3...4, 4...5]
        let scrambleRanges: [ClosedRange<Int>] = [2...3, 3...4, 4...6, 5...7, 7...9]
        let toothList: [Int] = [6, 8, 9, 10, 12, 14, 15, 16, 18, 20]
        let compassColumns: [Int] = [1, 1, 0, -1, -1, -1, 0, 1]
        let compassRows: [Int] = [0, 1, 1, 1, 0, -1, -1, -1]
        let band: Int = min(5, max(1, entry.band))
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        // 1. The wall.
        let width: Int = Int.random(in: 12...16, using: &random)
        let rows: Int = Int.random(in: 9...12, using: &random)
        // 2. The gear count and the lamp heights.
        let count: Int = Int.random(in: gearRanges[band - 1], using: &random)
        let lampHeights: Int = Int.random(in: lampRanges[band - 1], using: &random)
        // 3. Parents and tooth counts, redrawn until the divisor with the parent is at least 2.
        var parents: [Int?] = []
        var teeth: [Int] = []
        for gear in 0..<count {
            var parent: Int? = nil
            if gear > 0 { parent = Int.random(in: 0...(gear - 1), using: &random) }
            parents.append(parent)
            var tooth: Int = toothList[Int.random(in: 0...(toothList.count - 1), using: &random)]
            if let parent {
                while divisor(tooth, teeth[parent]) < 2 {
                    tooth = toothList[Int.random(in: 0...(toothList.count - 1), using: &random)]
                }
            }
            teeth.append(tooth)
        }
        // 4. The solution set-up.
        var solution: [Int] = []
        for gear in 0..<count { solution.append(Int.random(in: 0...(teeth[gear] - 1), using: &random)) }
        let solutionHeight: Int = Int.random(in: 0...(lampHeights - 1), using: &random)
        // 5. Blades, depth, centre and slots per gear; alignments are the solution's sums.
        var built: [MoonlitMechanismGear] = []
        for gear in 0..<count {
            let tooth: Int = teeth[gear]
            var blades: [Bool] = []
            for _ in 0..<tooth { blades.append(Int.random(in: 0...2, using: &random) == 0) }
            blades[0] = true
            blades[tooth - 1] = false
            let depth: Int = Int.random(in: 1...3, using: &random)
            let column: Int = Int.random(in: 3...(width - 4), using: &random)
            let row: Int = Int.random(in: 2...(rows - 5), using: &random)
            var slots: [[MoonlitMechanismCell]] = []
            for slot in 0..<tooth {
                let compassIndex: Int = (8 * slot) / tooth
                let length: Int = Int.random(in: 2...3, using: &random)
                var ray: [MoonlitMechanismCell] = []
                for step in 1...length {
                    ray.append(MoonlitMechanismCell(column: compassColumns[compassIndex] * step,
                                                    row: compassRows[compassIndex] * step))
                }
                slots.append(ray)
            }
            var alignment: Int = 0
            if let parent = parents[gear] {
                alignment = modulo(solution[parent] + solution[gear], divisor(teeth[parent], tooth))
            }
            built.append(MoonlitMechanismGear(teeth: tooth, phase: solution[gear], blades: blades, depth: depth,
                                              centre: MoonlitMechanismCell(column: column, row: row),
                                              parent: parents[gear], alignment: alignment, slots: slots))
        }
        let direction: [Int] = directions(parents)
        // 6. Key frames.
        let frameCount: Int = Int.random(in: frameRanges[band - 1], using: &random)
        var frames: [MoonlitMechanismKeyFrame] = []
        var turns: Int = Int.random(in: 0...2, using: &random)
        var covered: Set<Int> = []
        for frame in 0..<frameCount {
            var at: [Int] = []
            for gear in 0..<count { at.append(modulo(solution[gear] + direction[gear] * turns, teeth[gear])) }
            let cells: [Int] = castCells(built, phases: at, height: solutionHeight, width: width, rows: rows)
            if cells.isEmpty { return nil }
            for cell in cells { covered.insert(cell) }
            var required: Bool = true
            if frame > 0 { required = Int.random(in: 0...3, using: &random) != 0 }
            frames.append(MoonlitMechanismKeyFrame(turns: turns, target: cells, required: required))
            turns += Int.random(in: 1...4, using: &random)
        }
        // 7. Forbidden cells from the uncovered cells.
        var free: [Int] = []
        for cell in 0..<(width * rows) where !covered.contains(cell) { free.append(cell) }
        let drawnCount: Int = Int.random(in: 2...6, using: &random)
        let forbiddenCount: Int = drawnCount < free.count ? drawnCount : free.count
        var forbidden: [Int] = []
        for _ in 0..<forbiddenCount {
            let pick: Int = Int.random(in: 0...(free.count - 1), using: &random)
            forbidden.append(free[pick])
            free.remove(at: pick)
        }
        forbidden.sort()
        // 8. The scramble.
        var phases: [Int] = solution
        var height: Int = solutionHeight
        var netTurns: Int = 0
        var netLamp: Int = 0
        var netReseats: [Int] = Array(repeating: 0, count: count)
        let scramble: Int = Int.random(in: scrambleRanges[band - 1], using: &random)
        var done: Int = 0
        var draws: Int = 0
        while done < scramble && draws < 50 {
            draws += 1
            let kind: Int = Int.random(in: 0...2, using: &random)
            let step: Int = Bool.random(using: &random) ? 1 : -1
            if kind == 0 {
                for gear in 0..<count { phases[gear] = modulo(phases[gear] + direction[gear] * step, teeth[gear]) }
                netTurns += step
            } else if kind == 1 {
                let gear: Int = Int.random(in: 1...(count - 1), using: &random)
                phases[gear] = modulo(phases[gear] + step, teeth[gear])
                netReseats[gear] += step
            } else {
                if height + step < 0 || height + step >= lampHeights { continue }
                height += step
                netLamp += step
            }
            done += 1
        }
        if done == 0 { return nil }
        var start: [MoonlitMechanismGear] = []
        for gear in 0..<count {
            let value: MoonlitMechanismGear = built[gear]
            start.append(MoonlitMechanismGear(teeth: value.teeth, phase: phases[gear], blades: value.blades,
                                              depth: value.depth, centre: value.centre, parent: value.parent,
                                              alignment: value.alignment, slots: value.slots))
        }
        return Drawn(width: width, rows: rows, lampHeights: lampHeights, gears: start, solution: solution,
                     solutionHeight: solutionHeight, frames: frames, forbidden: forbidden, startPhases: phases,
                     startHeight: height, scramble: scramble, netTurns: netTurns, netLamp: netLamp,
                     netReseats: netReseats)
    }

    /// Records an issue for every value of `level` outside the band of `entry`.
    static func checkBand(_ level: MoonlitMechanismLevel, entry: MoonlitMechanismManifestEntry) {
        let profile: MoonlitMechanismBandProfile = .of(band: entry.band)
        #expect(profile.gears.contains(level.gears.count))
        #expect(profile.lampHeights.contains(level.lampHeights))
        #expect(profile.keyFrames.contains(level.keyFrames.count))
        #expect((12...16).contains(level.width))
        #expect((9...12).contains(level.rows))
        #expect(level.startingHeight >= 0 && level.startingHeight < level.lampHeights)
        for (index, gear) in level.gears.enumerated() {
            #expect(MoonlitMechanismGenerator.toothChoices.contains(gear.teeth))
            if index == 0 {
                #expect(gear.parent == nil)
                #expect(gear.alignment == 0)
            } else if let parent = gear.parent {
                #expect(parent < index)
                let g: Int = divisor(level.gears[parent].teeth, gear.teeth)
                #expect(g >= 2)
                #expect(gear.alignment >= 0 && gear.alignment < g)
            } else {
                Issue.record("a child gear without a parent")
            }
            #expect(gear.blades.count == gear.teeth)
            #expect(gear.blades.first == true)
            #expect(gear.blades.last == false)
            #expect((1...3).contains(gear.depth))
            #expect((3...(level.width - 4)).contains(gear.centre.column))
            #expect((2...(level.rows - 5)).contains(gear.centre.row))
            #expect(gear.slots.count == gear.teeth)
            for slot in 0..<gear.teeth {
                let ray: [MoonlitMechanismCell] = gear.slots[slot]
                let direction: MoonlitMechanismCell = MoonlitMechanismGenerator.compass[(8 * slot) / gear.teeth]
                #expect((2...3).contains(ray.count))
                for (offset, cell) in ray.enumerated() {
                    #expect(cell.column == direction.column * (offset + 1))
                    #expect(cell.row == direction.row * (offset + 1))
                }
            }
        }
        var targets: Set<Int> = []
        for (index, frame) in level.keyFrames.enumerated() {
            if index == 0 {
                #expect((0...2).contains(frame.turns))
                #expect(frame.required)
            } else {
                #expect((1...4).contains(frame.turns - level.keyFrames[index - 1].turns))
            }
            #expect(!frame.target.isEmpty)
            for cell in frame.target { targets.insert(cell) }
        }
        #expect((2...6).contains(level.forbidden.count))
        for cell in level.forbidden { #expect(!targets.contains(cell)) }
        #expect(level.allowance == 0)
        #expect(level.budget == entry.budget)
        #expect(level.tutorial == (entry.number <= 3))
        #expect(level.id == MoonlitMechanismGenerator.levelID(entry.number))
        #expect(level.difficulty == entry.band)
        #expect(level.seed == entry.seed)
    }

    /// Whether candidate `index` of `entry` passes every filter of `generate`, recomputed here.
    static func qualifies(_ entry: MoonlitMechanismManifestEntry, index: Int) -> Bool {
        guard let level = MoonlitMechanismGenerator.candidate(entry, index: index) else { return false }
        if level.run(phases: level.startingPhases, height: level.startingHeight).outcome == .won { return false }
        let range: ClosedRange<Int> = MoonlitMechanismBandProfile.of(band: entry.band).planRange
        guard let plan = MoonlitMechanismSolver.plan(level, maxActions: range.upperBound) else { return false }
        return range.contains(plan.size) && plan.size <= entry.budget - 1
    }

    /// Records an issue for every broken filter or metric of the certified levels of `band`.
    static func checkGenerated(_ generated: [MoonlitMechanismGenerated], band: Int) {
        #expect(generated.count == 20)
        let range: ClosedRange<Int> = MoonlitMechanismBandProfile.of(band: band).planRange
        for (offset, item) in generated.enumerated() {
            let number: Int = (band - 1) * 20 + 1 + offset
            let entry: MoonlitMechanismManifestEntry = entry(number)
            #expect(item.entry == entry)
            let level: MoonlitMechanismLevel = item.level
            checkBand(level, entry: entry)
            // The candidate it came from.
            #expect(MoonlitMechanismGenerator.candidate(entry, index: item.skipped) == level)
            #expect(item.skipped >= 0 && item.skipped < MoonlitMechanismGenerator.maxCandidates)
            // The filters.
            #expect(level.run(phases: level.startingPhases, height: level.startingHeight).outcome != .won)
            let plan: MoonlitMechanismPlan = item.plan
            #expect(range.contains(plan.size))
            #expect(plan.size <= entry.budget - 1)
            #expect(plan.reseats.count == level.gears.count)
            #expect(plan.reseats.first == 0)
            #expect(MoonlitMechanismSolver.plan(level, maxActions: range.upperBound) == plan)
            #expect(MoonlitMechanismSolver.wins(level, actions: item.actions))
            // Every earlier candidate fails a filter.
            for index in 0..<item.skipped { #expect(!qualifies(entry, index: index)) }
            // The difficulty, recounted.
            var size: Int = abs(plan.turns) + abs(plan.lamp)
            for reseat in plan.reseats { size += abs(reseat) }
            var teeth: Int = 0
            for gear in level.gears { teeth += gear.teeth }
            var required: Int = 0
            var targets: Int = 0
            for frame in level.keyFrames {
                if frame.required { required += 1 }
                targets += frame.target.count
            }
            let difficulty: MoonlitMechanismDifficulty = item.difficulty
            #expect(difficulty.actions == size)
            #expect(difficulty.actions == item.actions.count - 1)
            #expect(difficulty.gears == level.gears.count)
            #expect(difficulty.meshes == level.gears.count - 1)
            #expect(difficulty.teeth == teeth)
            #expect(difficulty.keyFrames == level.keyFrames.count)
            #expect(difficulty.requiredKeyFrames == required)
            #expect(difficulty.targetCells == targets)
            #expect(difficulty.forbiddenCells == level.forbidden.count)
            #expect(difficulty.lampHeights == level.lampHeights)
            #expect(difficulty.smallerVectors == plan.smallerVectors)
            #expect(difficulty.work == plan.work)
            #expect(difficulty.puzzleDifficulty == PuzzleDifficulty(shortest: size, explored: plan.work))
        }
    }

    @Test("the manifest holds 100 entries in order, 20 per band, budgets within the archived band values, distinct seeds")
    func manifest() {
        let entries: [MoonlitMechanismManifestEntry] = MoonlitMechanismManifest.entries
        #expect(entries.count == 100)
        var seeds: Set<UInt64> = []
        var perBand: [Int] = [0, 0, 0, 0, 0]
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1)
            #expect((1...5).contains(entry.band))
            #expect((8...19).contains(entry.budget))
            #expect(Self.budgetRanges[entry.band - 1].contains(entry.budget))
            perBand[entry.band - 1] += 1
            seeds.insert(entry.seed)
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        #expect(seeds.count == 100)
        #expect(!MoonlitMechanismManifest.source.isEmpty)
        #expect(!MoonlitMechanismManifest.provenance.isEmpty)
    }

    @Test("the band profiles equal clarification Q1 and out-of-range bands clamp")
    func bandProfiles() {
        let expected: [MoonlitMechanismBandProfile] = [
            MoonlitMechanismBandProfile(gears: 2...3, lampHeights: 2...3, keyFrames: 2...2, scramble: 2...3,
                                        planRange: 1...2),
            MoonlitMechanismBandProfile(gears: 3...3, lampHeights: 3...3, keyFrames: 2...3, scramble: 3...4,
                                        planRange: 2...3),
            MoonlitMechanismBandProfile(gears: 3...4, lampHeights: 3...4, keyFrames: 3...3, scramble: 4...6,
                                        planRange: 3...4),
            MoonlitMechanismBandProfile(gears: 4...4, lampHeights: 4...4, keyFrames: 3...4, scramble: 5...7,
                                        planRange: 4...5),
            MoonlitMechanismBandProfile(gears: 4...5, lampHeights: 4...5, keyFrames: 4...5, scramble: 7...9,
                                        planRange: 5...6),
        ]
        for band in 1...5 { #expect(MoonlitMechanismBandProfile.of(band: band) == expected[band - 1]) }
        #expect(MoonlitMechanismBandProfile.of(band: 0) == expected[0])
        #expect(MoonlitMechanismBandProfile.of(band: -3) == expected[0])
        #expect(MoonlitMechanismBandProfile.of(band: 6) == expected[4])
        // Neighbouring plan ranges meet at one value (clarification Q3).
        for band in 1...4 {
            #expect(expected[band - 1].planRange.upperBound == expected[band].planRange.lowerBound)
        }
        #expect(MoonlitMechanismSolver.maxActions == 6)
    }

    @Test("the level ids, the tooth list, the compass, the candidate bound and the catalog id")
    func constants() {
        #expect(MoonlitMechanismGenerator.levelID(1) == "moonlit-mechanism-001")
        #expect(MoonlitMechanismGenerator.levelID(42) == "moonlit-mechanism-042")
        #expect(MoonlitMechanismGenerator.levelID(100) == "moonlit-mechanism-100")
        #expect(MoonlitMechanismGenerator.toothChoices == [6, 8, 9, 10, 12, 14, 15, 16, 18, 20])
        #expect(MoonlitMechanismGenerator.maxCandidates == 256)
        #expect(MoonlitMechanismGenerator.catalogID == "moonlit-mechanism")
        let columns: [Int] = [1, 1, 0, -1, -1, -1, 0, 1]
        let rows: [Int] = [0, 1, 1, 1, 0, -1, -1, -1]
        #expect(MoonlitMechanismGenerator.compass.count == 8)
        for index in 0..<8 {
            #expect(MoonlitMechanismGenerator.compass[index] == MoonlitMechanismCell(column: columns[index],
                                                                                    row: rows[index]))
        }
    }

    @Test("candidates and generation are deterministic and different indices differ")
    func determinism() throws {
        for number in [1, 21, 41, 61, 81] {
            let entry: MoonlitMechanismManifestEntry = Self.entry(number)
            var levels: [MoonlitMechanismLevel] = []
            for index in 0..<8 {
                let first: MoonlitMechanismLevel? = MoonlitMechanismGenerator.candidate(entry, index: index)
                let second: MoonlitMechanismLevel? = MoonlitMechanismGenerator.candidate(entry, index: index)
                #expect(first == second)
                if let first { levels.append(first) }
            }
            #expect(levels.count >= 2)
            var fingerprints: Set<String> = []
            for level in levels { fingerprints.insert(level.fingerprint) }
            #expect(fingerprints.count == levels.count)
        }
        for number in [2, 22, 42] {
            let entry: MoonlitMechanismManifestEntry = Self.entry(number)
            let first: MoonlitMechanismGenerated = try MoonlitMechanismGenerator.generate(entry)
            let second: MoonlitMechanismGenerated = try MoonlitMechanismGenerator.generate(entry)
            #expect(first == second)
        }
    }

    @Test("the drawing order re-implemented independently matches every field of candidate(_:index:)")
    func drawingOrder() {
        var compared: Int = 0
        var discarded: Int = 0
        for number in Self.sampledNumbers {
            let entry: MoonlitMechanismManifestEntry = Self.entry(number)
            for index in 0..<Self.sampledIndices {
                let level: MoonlitMechanismLevel? = MoonlitMechanismGenerator.candidate(entry, index: index)
                guard let drawn = Self.redraw(entry, index: index) else {
                    #expect(level == nil)
                    discarded += 1
                    continue
                }
                guard let level else {
                    Issue.record("the generator discarded a candidate the re-draw keeps")
                    continue
                }
                compared += 1
                #expect(level.id == MoonlitMechanismGenerator.levelID(number))
                #expect(level.seed == entry.seed)
                #expect(level.difficulty == entry.band)
                #expect(level.width == drawn.width)
                #expect(level.rows == drawn.rows)
                #expect(level.lampHeights == drawn.lampHeights)
                #expect(level.startingHeight == drawn.startHeight)
                #expect(level.startingPhases == drawn.startPhases)
                #expect(level.gears == drawn.gears)
                #expect(level.keyFrames == drawn.frames)
                #expect(level.forbidden == drawn.forbidden)
                #expect(level.allowance == 0)
                #expect(level.budget == entry.budget)
                #expect(level.tutorial == (number <= 3))
            }
        }
        #expect(compared >= Self.sampledNumbers.count * 4)
        #expect(compared + discarded == Self.sampledNumbers.count * Self.sampledIndices)
    }

    @Test("every candidate respects its band and its start is a scramble of a winning solution")
    func candidateValues() {
        for number in Self.sampledNumbers {
            let entry: MoonlitMechanismManifestEntry = Self.entry(number)
            let profile: MoonlitMechanismBandProfile = .of(band: entry.band)
            for index in 0..<Self.sampledIndices {
                guard let level = MoonlitMechanismGenerator.candidate(entry, index: index),
                      let drawn = Self.redraw(entry, index: index) else { continue }
                Self.checkBand(level, entry: entry)
                #expect(profile.scramble.contains(drawn.scramble))
                // The solution set-up wins.
                #expect(level.run(phases: drawn.solution, height: drawn.solutionHeight).outcome == .won)
                // The start is the solution moved by the scramble's net vector.
                var norm: Int = abs(drawn.netTurns) + abs(drawn.netLamp)
                for reseat in drawn.netReseats { norm += abs(reseat) }
                #expect(norm <= drawn.scramble)
                #expect(drawn.netReseats.first == 0)
                #expect(level.startingHeight == drawn.solutionHeight + drawn.netLamp)
                var back: [Int] = level.startingPhases
                for gear in 1..<level.gears.count {
                    back[gear] = Self.modulo(back[gear] - drawn.netReseats[gear], level.gears[gear].teeth)
                }
                back = MoonlitMechanismTrain.turned(level.gears, phases: back, by: -drawn.netTurns)
                #expect(back == drawn.solution)
                // So a plan of at most that norm returns it to a winning set-up.
                if norm <= 4 {
                    let plan: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(level, maxActions: norm)
                    #expect(plan != nil)
                    if let plan { #expect(plan.size <= norm) }
                }
            }
        }
    }

    @Test("band 1 (levels 1 … 20): filters, skipped candidates, witness and difficulty")
    func generatedBand1() {
        Self.checkGenerated(Self.band1, band: 1)
    }

    @Test("band 2 (levels 21 … 40): filters, skipped candidates, witness and difficulty")
    func generatedBand2() {
        Self.checkGenerated(Self.band2, band: 2)
    }

    @Test("band 3 (levels 41 … 60): filters, skipped candidates, witness and difficulty")
    func generatedBand3() {
        Self.checkGenerated(Self.band3, band: 3)
    }

    @Test("band 4 (levels 61 … 80): filters, skipped candidates, witness and difficulty")
    func generatedBand4() {
        Self.checkGenerated(Self.band4, band: 4)
    }

    @Test("band 5 (levels 81 … 100): filters, skipped candidates, witness and difficulty")
    func generatedBand5() {
        Self.checkGenerated(Self.band5, band: 5)
    }

    @Test("an entry no candidate can satisfy is refused with generation(number)")
    func refusal() {
        let base: MoonlitMechanismManifestEntry = Self.entry(7)
        // A budget of 1 leaves no action before the run, so no plan of at least one action fits budget − 1.
        let impossible: MoonlitMechanismManifestEntry =
            MoonlitMechanismManifestEntry(number: base.number, seed: base.seed, band: base.band, budget: 1)
        var thrown: MoonlitMechanismError? = nil
        do {
            _ = try MoonlitMechanismGenerator.generate(impossible)
        } catch {
            thrown = error
        }
        #expect(thrown == .generation(7))
        #expect(thrown?.reasonCode == "r02-g14.generation")
        #expect(MoonlitMechanismError.generation(57).reasonCode == "r02-g14.generation")
    }

    @Test("the catalog digest is deterministic and order-sensitive")
    func catalogDigest() {
        let levels: [MoonlitMechanismLevel] = [Self.band1[0].level, Self.band2[0].level, Self.band3[0].level]
        let digest: String = MoonlitMechanismGenerator.catalogDigest(levels)
        #expect(!digest.isEmpty)
        #expect(digest == MoonlitMechanismGenerator.catalogDigest(levels))
        var swapped: [MoonlitMechanismLevel] = levels
        swapped.swapAt(0, 2)
        #expect(digest != MoonlitMechanismGenerator.catalogDigest(swapped))
        #expect(digest != MoonlitMechanismGenerator.catalogDigest(Array(levels.prefix(2))))
    }
}
