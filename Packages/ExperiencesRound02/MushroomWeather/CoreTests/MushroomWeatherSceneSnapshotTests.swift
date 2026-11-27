// MushroomWeatherSceneSnapshotTests — feature 493 (R02-G20-03) T-R02G2003-002 (FR-R02G2003-002, 003, 004;
// clarifications Q2, Q3). The palette (21 colours, each hex value round-tripped through its linear colour, the
// registered main values), the three quality tiers, and the scene snapshot of a certified catalog level: shown cycles
// 0, the middle, the last and out of range on both sides, every field equal to the kernel's run, each colony's in-band
// flag equal to its band at the shown cycle's field, the pods, growth cycles, vents, moonlight, failure, stage, actions
// and budget taken from the play, a won and a failed play, and immutability and equatability. Explicit types, plain
// loops.
import Foundation
import Testing
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherSceneSnapshotTests {
    /// Level 1 of the certified catalog.
    static let generated: MushroomWeatherGenerated = {
        do {
            return try MushroomWeatherGenerator.generate(MushroomWeatherManifest.entries[0], previous: nil)
        } catch {
            fatalError("level 1 does not generate: \(error)")
        }
    }()

    /// A play of level 1 in stage `playing`.
    static func playing() throws -> MushroomWeatherPlay {
        var play = MushroomWeatherPlay(level: generated.level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The `#RRGGBB` form of a linear colour.
    static func hex(_ colour: SIMD3<Double>) -> String {
        let r: Int = Int((colour.x * 255).rounded())
        let g: Int = Int((colour.y * 255).rounded())
        let b: Int = Int((colour.z * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    @Test func paletteHasTwentyOneColoursThatRoundTrip() {
        #expect(MushroomWeatherPalette.all.count == 21)
        var names: Set<String> = []
        for entry in MushroomWeatherPalette.all {
            names.insert(entry.name)
            #expect(Self.hex(entry.colour) == entry.hex, "\(entry.name)")
            for component in [entry.colour.x, entry.colour.y, entry.colour.z] {
                #expect(component >= 0 && component <= 1)
            }
        }
        #expect(names.count == 21)
        #expect(Self.hex(MushroomWeatherPalette.midnight) == "#050A1A")
        #expect(Self.hex(MushroomWeatherPalette.glow) == "#F7FFF9")
        #expect(Self.hex(MushroomWeatherPalette.broken) == "#FF6B5E")
        #expect(MushroomWeatherPalette.hex == ["#050A1A", "#5FD3A0", "#F2A93B", "#3A6FD8", "#12261C"])
        let all: Set<String> = Set(MushroomWeatherPalette.all.map(\.hex))
        for value in MushroomWeatherPalette.hex { #expect(all.contains(value)) }
    }

    @Test func tiersFollowClarificationQ2() {
        let tiers: [MushroomWeatherTier] = MushroomWeatherTier.all
        #expect(tiers.map(\.name) == ["level-0", "level-1", "level-2"])
        #expect(tiers.map(\.index) == [0, 1, 2])
        #expect(tiers.map(\.latheSegments) == [16, 10, 0])
        #expect(tiers.map(\.droplets) == [12, 6, 0])
        #expect(tiers.map(\.fronds) == [true, true, false])
        #expect(tiers.map(\.motes) == [8, 4, 0])
        #expect(tiers.map(\.glowShells) == [2, 1, 0])
        #expect(tiers.map(\.flatCaps) == [false, false, true])
        #expect(MushroomWeatherTier.of(-3) == tiers[0])
        #expect(MushroomWeatherTier.of(1) == tiers[1])
        #expect(MushroomWeatherTier.of(9) == tiers[2])
    }

    @Test func snapshotCopiesTheKernelAtEveryShownCycle() throws {
        let play: MushroomWeatherPlay = try Self.playing()
        let level: MushroomWeatherLevel = play.level
        let run = MushroomWeatherForest.run(level, arrangement: play.arrangement, keepFields: true)
        let cycles: Int = run.report.cycles
        #expect(cycles >= 1)
        let requests: [(asked: Int, shown: Int)] = [(0, 0), (cycles / 2, cycles / 2), (cycles, cycles),
                                                    (cycles + 7, cycles), (-4, 0)]
        for request in requests {
            let snapshot = MushroomWeatherSceneSnapshot(play: play, shownCycle: request.asked, levelNumber: 1,
                                                        time: 2.5)
            #expect(snapshot.shownCycle == request.shown)
            #expect(snapshot.cyclesRun == cycles)
            #expect(snapshot.fields == run.fields)
            #expect(snapshot.fields.count == cycles + 1)
            #expect(snapshot.fields[0] == level.humidity)
            #expect(snapshot.shownField == run.fields[request.shown])
            #expect(snapshot.rows == level.rows && snapshot.columns == level.columns)
            #expect(snapshot.blocked == level.blocked)
            #expect(snapshot.moldBound == level.moldBound)
            #expect(snapshot.requiredCycles == level.required)
            #expect(snapshot.pods == play.arrangement.pods)
            #expect(snapshot.grownAt == run.report.grownAt)
            #expect(snapshot.sites == (level.sites ?? []))
            #expect(snapshot.vents == level.vents.map(\.cell))
            #expect(snapshot.ventsOpen == play.arrangement.ventsOpen)
            #expect(snapshot.moonlight == play.arrangement.moonlight)
            #expect(snapshot.failure == run.report.failure)
            #expect(snapshot.stage == .playing)
            #expect(snapshot.actionsLeft == level.budget && snapshot.budget == level.budget)
            #expect(snapshot.levelNumber == 1 && snapshot.time == 2.5)
            #expect(snapshot.colonies.count == level.colonies.count)
            for (index, colony) in level.colonies.enumerated() {
                let scene: MushroomWeatherSceneColony = snapshot.colonies[index]
                let humidity: Int = run.fields[request.shown][level.index(of: colony.cell)]
                #expect(scene.cell == colony.cell)
                #expect(scene.low == colony.low && scene.high == colony.high)
                #expect(scene.survivalFloor == colony.survivalFloor)
                #expect(scene.finalRun == run.report.colonies[index].finalRun)
                #expect(scene.longestRun == run.report.colonies[index].longestRun)
                #expect(scene.inBand == (colony.low <= humidity && humidity <= colony.high))
                #expect(snapshot.humidity(colony.cell) == humidity)
            }
        }
    }

    @Test func wonAndFailedPlaysAreCopied() throws {
        var won: MushroomWeatherPlay = try Self.playing()
        for action in Self.generated.plan.actions { try won.apply(action, expecting: won.fingerprint) }
        try won.apply(.run, expecting: won.fingerprint)
        #expect(won.stage == .won)
        let wonSnapshot = MushroomWeatherSceneSnapshot(play: won, shownCycle: .max, levelNumber: 1, time: 0)
        #expect(wonSnapshot.isWon && wonSnapshot.failure == nil)
        #expect(wonSnapshot.shownCycle == wonSnapshot.cyclesRun)
        #expect(wonSnapshot.pods == Self.generated.plan.arrangement.pods)
        #expect(wonSnapshot.actionsLeft == won.actionsLeft)
        for colony in wonSnapshot.colonies {
            #expect(colony.inBand && colony.finalRun >= wonSnapshot.requiredCycles)
        }
        for slot in wonSnapshot.grownAt.indices {
            if let cycle = wonSnapshot.grownAt[slot] {
                #expect(wonSnapshot.isGrown(slot))
                let early = MushroomWeatherSceneSnapshot(play: won, shownCycle: cycle - 1, levelNumber: 1, time: 0)
                #expect(!early.isGrown(slot))
            } else {
                #expect(!wonSnapshot.isGrown(slot))
            }
        }

        var failed: MushroomWeatherPlay = try Self.playing()
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let failedSnapshot = MushroomWeatherSceneSnapshot(play: failed, shownCycle: 3, levelNumber: 1, time: 0)
        #expect(!failedSnapshot.isWon)
        #expect(failedSnapshot.failure != nil && failedSnapshot.failure == failed.failure)
        #expect(failedSnapshot.stage == .failed)
    }

    @Test func snapshotsAreImmutableValuesAndEquatable() throws {
        var play: MushroomWeatherPlay = try Self.playing()
        let a = MushroomWeatherSceneSnapshot(play: play, shownCycle: 2, levelNumber: 1, time: 1)
        let b = MushroomWeatherSceneSnapshot(play: play, shownCycle: 2, levelNumber: 1, time: 1)
        #expect(a == b)
        #expect(a != MushroomWeatherSceneSnapshot(play: play, shownCycle: 3, levelNumber: 1, time: 1))
        #expect(a != MushroomWeatherSceneSnapshot(play: play, shownCycle: 2, levelNumber: 2, time: 1))
        #expect(a != MushroomWeatherSceneSnapshot(play: play, shownCycle: 2, levelNumber: 1, time: 1.5))
        // A later change to the play leaves an earlier snapshot as it was.
        let fields: [[Int]] = a.fields
        let action: MushroomWeatherAction = Self.generated.plan.actions[0]
        try play.apply(action, expecting: play.fingerprint)
        let c = MushroomWeatherSceneSnapshot(play: play, shownCycle: 2, levelNumber: 1, time: 1)
        #expect(a.fields == fields && a == b)
        #expect(c != a)
        #expect(c.actionsLeft == a.actionsLeft - 1)
        // Time is made finite and non-negative.
        #expect(MushroomWeatherSceneSnapshot(play: play, shownCycle: 0, levelNumber: 1, time: -3).time == 0)
        #expect(MushroomWeatherSceneSnapshot(play: play, shownCycle: 0, levelNumber: 1, time: .nan).time == 0)
        #expect(MushroomWeatherSceneSnapshot(play: play, shownCycle: 0, levelNumber: 1, time: .infinity).time == 0)
    }
}
