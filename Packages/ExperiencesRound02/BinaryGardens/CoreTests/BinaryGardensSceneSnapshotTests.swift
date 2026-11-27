// BinaryGardensSceneSnapshotTests — feature 503 (R02-G21-03) T-R02G2103-002 (FR-R02G2103-002, 003, 004;
// clarifications Q2, Q3; data-model.md). The palette (27 colours, each hex value round-tripped through its linear
// colour, the registered main values), the three quality tiers and `of(_:)` clamping, and the scene snapshot of a
// certified catalog level: shown ticks 1, 17, 24, 47 and 48 and out of range on both sides, every world's positions,
// flux, shares, bands, runs, window, start, integral and bloom equal to the kernel's report, both stars' positions,
// the arrangement, the fit scale 0.95 / R, the failure, stage, actions and budget taken from the play, the band and
// share at the shown tick, a won and a failed play, time clamping, and immutability and equatability. Explicit types,
// plain loops.
import Foundation
import Testing
@testable import BinaryGardensCore

@Suite struct BinaryGardensSceneSnapshotTests {
    /// Level 1 of the certified catalog (its witness's candidate).
    static let generated: BinaryGardensGenerated = {
        do {
            return try BinaryGardensExperienceCore.generated(number: 1)
        } catch {
            fatalError("level 1 does not generate: \(error)")
        }
    }()

    /// A play of level 1 in stage `playing`.
    static func playing() throws -> BinaryGardensPlay {
        var play = BinaryGardensPlay(level: generated.level)
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

    @Test func paletteHasTwentySevenColoursThatRoundTrip() {
        #expect(BinaryGardensPalette.all.count == 27)
        var names: Set<String> = []
        for entry in BinaryGardensPalette.all {
            names.insert(entry.name)
            #expect(Self.hex(entry.colour) == entry.hex, "\(entry.name)")
            for component in [entry.colour.x, entry.colour.y, entry.colour.z] {
                #expect(component >= 0 && component <= 1)
            }
        }
        #expect(names.count == 27)
        let expected: [String] = ["#070815", "#151B3D", "#C8D2F0", "#2B3560", "#3A6B66", "#FF5A36", "#A6DDFF",
                                  "#FFF4E8", "#7BE8BE", "#DDF2FF", "#C2412A", "#FFE6F2", "#FFE6F2", "#1A2347",
                                  "#5C8DFF", "#8FB8E0", "#7BE8BE", "#FFB27A", "#FF4A3D", "#B8FFE0", "#FFF4E8",
                                  "#A6DDFF", "#2B3560", "#FF7A4D", "#1E2648", "#FF6B5E", "#FFF9F0"]
        var listed: [String] = []
        for entry in BinaryGardensPalette.all { listed.append(entry.hex) }
        #expect(listed == expected)
        #expect(Self.hex(BinaryGardensPalette.space) == "#070815")
        #expect(Self.hex(BinaryGardensPalette.starOne) == "#FF5A36")
        #expect(Self.hex(BinaryGardensPalette.starTwo) == "#A6DDFF")
        #expect(Self.hex(BinaryGardensPalette.world) == "#7BE8BE")
        #expect(Self.hex(BinaryGardensPalette.broken) == "#FF6B5E")
        #expect(Self.hex(BinaryGardensPalette.glow) == "#FFF9F0")
        #expect(BinaryGardensPalette.hex == ["#070815", "#FF5A36", "#A6DDFF", "#7BE8BE", "#151B3D"])
        let all: Set<String> = Set(listed)
        for value in BinaryGardensPalette.hex { #expect(all.contains(value)) }
    }

    @Test func tiersFollowClarificationQ2() {
        let tiers: [BinaryGardensTier] = BinaryGardensTier.all
        #expect(tiers.map(\.name) == ["level-0", "level-1", "level-2"])
        #expect(tiers.map(\.index) == [0, 1, 2])
        #expect(tiers.map(\.faceQuads) == [8, 5, 3])
        #expect(tiers.map(\.coronaRays) == [12, 6, 0])
        #expect(tiers.map(\.trailTicks) == [8, 4, 0])
        #expect(tiers.map(\.motes) == [8, 4, 0])
        #expect(tiers.map(\.glowShells) == [2, 1, 0])
        #expect(BinaryGardensTier.of(-3) == tiers[0])
        #expect(BinaryGardensTier.of(1) == tiers[1])
        #expect(BinaryGardensTier.of(9) == tiers[2])
    }

    @Test func snapshotCopiesTheKernelAtEveryShownTick() throws {
        let play: BinaryGardensPlay = try Self.playing()
        let level: BinaryGardensLevel = play.level
        let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: play.arrangement)
        #expect(report == play.report)
        let requests: [(asked: Int, shown: Int)] = [(1, 1), (17, 17), (24, 24), (47, 47), (48, 48), (0, 1),
                                                    (-4, 1), (49, 48), (60, 48)]
        var largest: Int = 1
        for radius in level.ringRadii { largest = max(largest, radius) }
        for world in level.worlds { largest = max(largest, world.radius) }
        for request in requests {
            let snapshot = BinaryGardensSceneSnapshot(play: play, shownTick: request.asked, levelNumber: 1, time: 2.5)
            #expect(snapshot.shownTick == request.shown)
            #expect(snapshot.ringRadii == level.ringRadii && snapshot.luminosityLevels == level.luminosityLevels)
            #expect(snapshot.maxTilt == level.maxTilt && snapshot.phaseStep == level.phaseStep)
            #expect(snapshot.lethalTolerance == level.lethalTolerance)
            #expect(snapshot.arrangement == play.arrangement)
            #expect(snapshot.starPositions == report.starPositions && snapshot.starPositions.count == 48)
            #expect(abs(snapshot.fitScale - 0.95 / Double(largest)) < 1e-15)
            #expect(snapshot.failure == report.failure && snapshot.stage == .playing)
            #expect(snapshot.actionsLeft == level.budget && snapshot.budget == level.budget)
            #expect(snapshot.levelNumber == 1 && snapshot.time == 2.5)
            #expect(snapshot.worlds.count == level.worlds.count)
            for (index, world) in level.worlds.enumerated() {
                let scene: BinaryGardensSceneWorld = snapshot.worlds[index]
                let light: BinaryGardensWorldLight = report.worlds[index]
                #expect(scene.radius == world.radius && scene.phase == world.phase && scene.speed == world.speed)
                #expect(scene.lethalLow == world.lethalLow && scene.comfortLow == world.comfortLow)
                #expect(scene.comfortHigh == world.comfortHigh && scene.lethalHigh == world.lethalHigh)
                #expect(scene.window == world.window && scene.bloomLow == world.bloomLow)
                #expect(scene.bloomHigh == world.bloomHigh)
                #expect(scene.flux == light.flux && scene.shares == light.shares && scene.bands == light.bands)
                #expect(scene.longestLethalRun == light.longestLethalRun && scene.longestWindow == light.window)
                #expect(scene.windowStart == light.windowStart && scene.integral == light.integral)
                #expect(scene.bloom == light.bloom)
                for tick in 1...48 {
                    #expect(scene.positions[tick - 1] == report.worldPositions[tick - 1][index])
                    #expect(snapshot.worldPoint(index, tick: tick) == report.worldPositions[tick - 1][index])
                }
                #expect(snapshot.band(index) == light.bands[request.shown - 1])
                #expect(snapshot.share(index, star: 0) == light.shares[request.shown - 1][0])
                #expect(snapshot.share(index, star: 1) == light.shares[request.shown - 1][1])
            }
            for star in 0..<2 {
                #expect(snapshot.starPoint(star, tick: request.shown) == report.starPositions[request.shown - 1][star])
                // Ticks read cyclically: tick 49 is tick 1 and tick 0 is tick 48.
                #expect(snapshot.starPoint(star, tick: 49) == report.starPositions[0][star])
                #expect(snapshot.starPoint(star, tick: 0) == report.starPositions[47][star])
            }
        }
    }

    @Test func wonAndFailedPlaysAreCopied() throws {
        var won: BinaryGardensPlay = try Self.playing()
        for action in Self.generated.plan.actions { try won.apply(action, expecting: won.fingerprint) }
        try won.apply(.run, expecting: won.fingerprint)
        #expect(won.stage == .won)
        let wonSnapshot = BinaryGardensSceneSnapshot(play: won, shownTick: 24, levelNumber: 1, time: 0)
        #expect(wonSnapshot.isWon && wonSnapshot.failure == nil)
        #expect(wonSnapshot.arrangement == Self.generated.plan.arrangement)
        #expect(wonSnapshot.actionsLeft == won.actionsLeft)
        for world in wonSnapshot.worlds { #expect(world.longestWindow >= world.window && world.bloom == .inside) }
        try won.handle(.showResult)
        #expect(BinaryGardensSceneSnapshot(play: won, shownTick: 24, levelNumber: 1, time: 0).isWon)

        var failed: BinaryGardensPlay = try Self.playing()
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let failedSnapshot = BinaryGardensSceneSnapshot(play: failed, shownTick: 3, levelNumber: 1, time: 0)
        #expect(!failedSnapshot.isWon)
        #expect(failedSnapshot.failure != nil && failedSnapshot.failure == failed.failure)
        #expect(failedSnapshot.stage == .failed)
        try failed.handle(.showResult)
        #expect(!BinaryGardensSceneSnapshot(play: failed, shownTick: 3, levelNumber: 1, time: 0).isWon)
    }

    @Test func snapshotsAreImmutableValuesAndEquatable() throws {
        var play: BinaryGardensPlay = try Self.playing()
        let a = BinaryGardensSceneSnapshot(play: play, shownTick: 2, levelNumber: 1, time: 1)
        let b = BinaryGardensSceneSnapshot(play: play, shownTick: 2, levelNumber: 1, time: 1)
        #expect(a == b)
        #expect(a != BinaryGardensSceneSnapshot(play: play, shownTick: 3, levelNumber: 1, time: 1))
        #expect(a != BinaryGardensSceneSnapshot(play: play, shownTick: 2, levelNumber: 2, time: 1))
        #expect(a != BinaryGardensSceneSnapshot(play: play, shownTick: 2, levelNumber: 1, time: 1.5))
        // A later change to the play leaves an earlier snapshot as it was.
        let worlds: [BinaryGardensSceneWorld] = a.worlds
        let action: BinaryGardensAction = Self.generated.plan.actions[0]
        try play.apply(action, expecting: play.fingerprint)
        let c = BinaryGardensSceneSnapshot(play: play, shownTick: 2, levelNumber: 1, time: 1)
        #expect(a.worlds == worlds && a == b)
        #expect(c != a)
        #expect(c.actionsLeft == a.actionsLeft - 1)
        // Time is made finite and non-negative.
        #expect(BinaryGardensSceneSnapshot(play: play, shownTick: 1, levelNumber: 1, time: -3).time == 0)
        #expect(BinaryGardensSceneSnapshot(play: play, shownTick: 1, levelNumber: 1, time: .nan).time == 0)
        #expect(BinaryGardensSceneSnapshot(play: play, shownTick: 1, levelNumber: 1, time: .infinity).time == 0)
        #expect(BinaryGardensSceneSnapshot.fitScale(ringRadii: [5, 6, 8], worldRadii: [24]) == 0.95 / 24)
        #expect(BinaryGardensSceneSnapshot.fitScale(ringRadii: [], worldRadii: []) == 0.95)
        #expect(BinaryGardensSceneSnapshot.tickIndex(1) == 0 && BinaryGardensSceneSnapshot.tickIndex(48) == 47)
        #expect(BinaryGardensSceneSnapshot.tickIndex(60) == 11 && BinaryGardensSceneSnapshot.tickIndex(0) == 47)
    }
}
