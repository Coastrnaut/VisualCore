// BinaryGardensRegressionGoldenTests — feature 508 (R02-G21-08) T-R02G2108-004 (FR-R02G2108-003, 004; SC-R02G2108-003;
// clarification Q3). The code-only visual baseline of Binary Gardens: the fixed golden set of 17 frames (levels 1, 21,
// 41, 61, 81 at tiers 0, 1, 2, then level 25 at tier 0 for its full tilt dial, each at time 0 after all of the stored
// witness's arrangement actions — `docs/games/binary-gardens/levels/NNN.witness.json` without its final run — but not
// the run, with tick 24 shown as the feature-503 frame checks; then the hero frame: the level the hero scenario opens,
// seed `manifestSeed`, after the same actions with the hero tick shown, tier 0) in its fixed order with unique names;
// every frame is still open, its actions bars are partly spent and the run then wins it; every frame's counts and
// values match the snapshot, its palette (27 colours) is the Core's and its material table (42 entries, codes 0 … 41)
// the shaders'; level 25 alone has a tilt dial and a first tilt pip; the tiers of a level share every position and
// count; deterministic descriptions and digests; every frame's recomputed description against the pinned file
// BinaryGardens/golden-frames.json, which holds exactly the 17 frame names under schema 1 and equals `manifest()` for
// the current code; every pinned digest against the digest of its pinned description; and the failures the comparison
// must name, built from the pinned manifest in memory (the pinned file is never written by them): the barycentre, a
// world, a star, the gauge margin, the first actions bar or the first tilt pip moved by two 1/8-pixel quanta fails
// naming the frame while one quantum passes, a changed palette colour, a changed, added or removed material entry, a
// changed count (naming it), a changed tick, tilt, star value or world window, a changed identity or size, a missing
// frame, a renamed or unknown frame, an unknown extra entry in the file (checked by name equality, as `compare` looks
// up one frame at a time), a schema other than 1, an unreadable file and a hand-edited description that kept its old
// digest. A position may be null in the schema (a point behind the eye, or no tilt dial); the helpers that pick a
// position to move skip nulls. `writeIfRequested` is exercised on a temporary file only: it writes nothing without the
// switch and exactly the manifest with it.
//
// The pinned file is written only when BINARY_GARDENS_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     BINARY_GARDENS_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter BinaryGardensRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule), and no `try` inside
// `#expect`. Synthetic data only; no wall-clock asserts. Modelled on MushroomWeatherRegressionGoldenTests (feature 498).
import Foundation
import Testing
import VisualCoreMath
@testable import BinaryGardensCore

/// File-private helpers of the golden tests, kept in one namespace so no name collides with other files of the target.
private enum GoldenSupport {
    /// The pinned golden file, found from this file (…/BinaryGardens/CoreTests/ → ../golden-frames.json).
    static let file: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("golden-frames.json", isDirectory: false)

    /// The repository's witness directory, found from this file (five levels up: CoreTests, BinaryGardens, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/binary-gardens/levels", isDirectory: true)

    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[BinaryGardensGolden.writeSwitch] == "1"
    }

    /// The 17 frame names in their fixed order.
    static let expectedNames: [String] = [
        "level-001-tier-0", "level-001-tier-1", "level-001-tier-2",
        "level-021-tier-0", "level-021-tier-1", "level-021-tier-2",
        "level-041-tier-0", "level-041-tier-1", "level-041-tier-2",
        "level-061-tier-0", "level-061-tier-1", "level-061-tier-2",
        "level-081-tier-0", "level-081-tier-1", "level-081-tier-2",
        "level-025-tier-0",
        "hero",
    ]

    /// The 27 described palette colours in declaration order.
    static let colourNames: [String] = [
        "space", "spaceTop", "starfield", "ringIdle", "orbit", "starOne", "starTwo", "core", "world", "frost",
        "scorch", "flower", "pollen", "gaugePlate", "lethalLow", "dim", "comfortable", "bright", "lethalHigh",
        "window", "marker", "tiltLit", "tiltUnlit", "actionsLit", "actionsUnlit", "broken", "glow",
    ]

    /// The count keys of a description.
    static let scalarCountKeys: [String] = [
        "rings", "starRings", "worlds", "shortBrackets", "tiltPipsLit", "tiltPips", "luminosityPipsLit",
        "luminosityPips", "actionsLit", "actions", "broken",
    ]

    /// The band-list count keys of a description (five entries each).
    static let bandCountKeys: [String] = ["worldsByBand", "cellsByBand"]

    /// The stored witness of level `number`.
    static func witness(_ number: Int) throws -> BinaryGardensWitness {
        let name: String = String(BinaryGardensGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try BinaryGardensWitness.decode(data)
    }

    /// The stored witness's arrangement actions of level `number`: its actions, which end with the run, without the
    /// run.
    static func witnessChanges(_ number: Int) throws -> [BinaryGardensAction] {
        let stored: BinaryGardensWitness = try witness(number)
        #expect(stored.actions.last == .run, "witness \(number) does not end with the run")
        var changes: [BinaryGardensAction] = []
        for action in stored.actions where action != .run { changes.append(action) }
        return changes
    }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: file.path) { return try Data(contentsOf: file) }
        return try BinaryGardensGolden.manifest()
    }

    /// The manifest as a mutable JSON tree.
    static func tree(_ data: Data) throws -> [String: Any] {
        let object: Any = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    /// The JSON bytes of a tree, keys sorted.
    static func bytes(_ tree: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: tree, options: [.sortedKeys])
    }

    /// The digest of `description` as the Core encodes it.
    static func digest(of description: [String: Any]) throws -> String {
        let data: Data = try JSONSerialization.data(withJSONObject: description)
        let decoded: BinaryGardensGolden.Description = try JSONDecoder().decode(
            BinaryGardensGolden.Description.self, from: data)
        return try BinaryGardensGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in BinaryGardensGolden.frames { expected.insert(frame.name) }
        var pinned: Set<String> = []
        for key in frames.keys { pinned.insert(key) }
        for name in pinned.subtracting(expected).sorted() { return "golden-frames.json has unknown frame \(name)" }
        for name in expected.subtracting(pinned).sorted() { return "golden-frames.json has no frame \(name)" }
        return nil
    }

    /// The manifest `data` with the entry of `frame` replaced by `edit` applied to its description and, when `redigest`
    /// is true, the digest of the edited description, so the entry stays self-consistent and `compare` takes the
    /// tolerance path; when false the old digest is kept (a hand edit).
    static func edited(_ data: Data, frame: String, redigest: Bool = true,
                       _ edit: (inout [String: Any]) throws -> Void) throws -> Data {
        var root: [String: Any] = try tree(data)
        var frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var entry: [String: Any] = try #require(frames[frame] as? [String: Any])
        var description: [String: Any] = try #require(entry["description"] as? [String: Any])
        try edit(&description)
        entry["description"] = description
        if redigest { entry["digest"] = try digest(of: description) }
        frames[frame] = entry
        root["frames"] = frames
        return try bytes(root)
    }

    /// The manifest `data` with the integer field `key` of `frame`'s description shifted by `delta`.
    static func shifted(_ data: Data, frame: String, key: String, by delta: Int) throws -> Data {
        try edited(data, frame: frame) { description in
            let value: Int = try #require(description[key] as? Int)
            description[key] = value + delta
        }
    }

    /// The manifest `data` with the scalar count `key` of `frame`'s description shifted by `delta`.
    static func shiftedCount(_ data: Data, frame: String, key: String, by delta: Int) throws -> Data {
        try edited(data, frame: frame) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            let value: Int = try #require(counts[key] as? Int)
            counts[key] = value + delta
            description["counts"] = counts
        }
    }

    /// The manifest `data` with entry `index` of the band-list count `key` of `frame`'s description shifted by
    /// `delta`.
    static func shiftedBandCount(_ data: Data, frame: String, key: String, index: Int, by delta: Int) throws -> Data {
        try edited(data, frame: frame) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            var list: [Int] = try #require(counts[key] as? [Int])
            try #require(list.indices.contains(index))
            list[index] += delta
            counts[key] = list
            description["counts"] = counts
        }
    }

    /// The manifest `data` with the integer `field` of entry `index` of the list `key` (`starValues`, `windows`,
    /// `materials`) of `frame`'s description shifted by `delta`.
    static func shiftedListField(_ data: Data, frame: String, key: String, index: Int, field: String,
                                 by delta: Int) throws -> Data {
        try edited(data, frame: frame) { description in
            var list: [Any] = try #require(description[key] as? [Any])
            try #require(list.indices.contains(index))
            var item: [String: Any] = try #require(list[index] as? [String: Any])
            let value: Int = try #require(item[field] as? Int)
            item[field] = value + delta
            list[index] = item
            description[key] = list
        }
    }

    /// `point` (a JSON position `[x, y]`) moved by `dx`, `dy` quanta.
    static func movedPoint(_ point: Any?, dx: Int, dy: Int) throws -> [Int] {
        let position: [Int] = try #require(point as? [Int])
        try #require(position.count == 2)
        return [position[0] + dx, position[1] + dy]
    }

    /// The manifest `data` with position `index` (0-based) of the list `key` (`worlds`, `stars`) of `frame`'s
    /// description moved by `dx`, `dy` quanta.
    static func movedListPoint(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0,
                               dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// The manifest `data` with the single position `key` (`barycentre`, `gaugeMargin`, `firstActionsBar`,
    /// `firstTiltPip`) of `frame` moved by `dx`, `dy` quanta.
    static func movedSingle(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// A pinned position of the list `key`: the first golden frame (in the fixed order) whose pinned description has
    /// one that projects (not null), and its 0-based index; nil when no frame has one.
    static func firstPlacedListPoint(_ data: Data, key: String) throws -> (frame: String, index: Int)? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in BinaryGardensGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description[key] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        return nil
    }

    /// The first golden frame (in the fixed order) whose pinned description has the single position `key` (not null).
    static func firstPlacedSingle(_ data: Data, key: String) throws -> String {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in BinaryGardensGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> BinaryGardensGolden.Frame {
        for frame in BinaryGardensGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The index of `band` in the counts' order (lethal low, dim, comfortable, bright, lethal high).
    static func bandIndex(_ band: BinaryGardensBand) -> Int {
        switch band {
        case .lethalLow: return 0
        case .dim: return 1
        case .comfortable: return 2
        case .bright: return 3
        case .lethalHigh: return 4
        }
    }
}

/// The code-only golden frames of Binary Gardens against the pinned file (see the file header).
@Suite struct BinaryGardensRegressionGoldenTests {
    /// The 17 frames, their order, unique names, levels, tiers, time, actions and ticks; each level frame applies all
    /// of its stored witness's arrangement actions (never the run) with tick 24 shown; the hero frame applies the hero
    /// level's actions and shows the hero tick.
    @Test func theGoldenSetIsFixed() throws {
        typealias Core = BinaryGardensExperienceCore
        let frames: [BinaryGardensGolden.Frame] = BinaryGardensGolden.frames
        #expect(frames.count == 17)
        var actualNames: [String] = []
        var names: Set<String> = []
        for frame in frames {
            actualNames.append(frame.name)
            names.insert(frame.name)
        }
        #expect(names.count == 17)
        #expect(actualNames == GoldenSupport.expectedNames)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(BinaryGardensGolden.levels == levels)
        #expect(BinaryGardensGolden.dialLevel == 25)
        #expect(BinaryGardensGolden.tick == 24)
        #expect(BinaryGardensGolden.width == 1_152)
        #expect(BinaryGardensGolden.height == 768)
        #expect(BinaryGardensGolden.schema == 1)
        #expect(BinaryGardensGolden.quantum == 8)
        #expect(BinaryGardensGolden.time == 0)
        #expect(BinaryGardensGolden.writeSwitch == "BINARY_GARDENS_WRITE_GOLDEN")
        #expect(BinaryGardensGolden.colourNames == GoldenSupport.colourNames)
        try #require(frames.count == 17)
        var index: Int = 0
        for level in levels + [25] {
            let changes: [BinaryGardensAction] = try GoldenSupport.witnessChanges(level)
            #expect(!changes.isEmpty, "level \(level) witness has no arrangement action")
            #expect(Core.certifiedActions(level) == changes, "level \(level) certified plan is not the witness's")
            let tiers: Int = level == 25 ? 1 : 3
            for tier in 0..<tiers {
                let frame: BinaryGardensGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.tick == 24, "\(frame.name) tick \(frame.tick)")
                #expect(frame.name == BinaryGardensGolden.name(level: level, tier: tier))
                #expect(frame.actions == changes, "\(frame.name) actions")
                #expect(!frame.actions.contains(.run), "\(frame.name) applies the run")
                index += 1
            }
        }
        let hero: BinaryGardensGolden.Frame = frames[16]
        #expect(hero.name == "hero")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        let heroChanges: [BinaryGardensAction] = try GoldenSupport.witnessChanges(heroLevel)
        #expect(hero.actions == heroChanges)
        #expect(!hero.actions.contains(.run), "hero applies the run")
        let heroTick: Int = try #require(Core.heroTick(heroLevel))
        #expect(hero.tick == heroTick, "hero tick \(hero.tick)")
        // The hero scenario is the certified actions, then one shown tick.
        #expect(Core.heroEntries.count == hero.actions.count + 1)
    }

    /// No action is applied for a level that cannot be generated.
    @Test func aLevelOutsideTheCatalogAppliesNoAction() {
        let outside: [Int] = [0, 101]
        for number in outside {
            #expect(BinaryGardensGolden.openActions(number).isEmpty, "level \(number) applies an action")
        }
    }

    /// Every frame is still open: stage `playing`, the predicted run wins, no preview, no inspected world, the actions
    /// bars partly spent, the frame's tick shown, and the run then wins it.
    @Test func everyFrameIsOpenAndTheRunWinsIt() throws {
        for frame in BinaryGardensGolden.frames {
            let level: BinaryGardensLevel = try BinaryGardensExperienceCore.level(number: frame.level)
            var play: BinaryGardensPlay = try BinaryGardensExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: BinaryGardensSceneSnapshot = try BinaryGardensGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) predicts a failure")
            #expect(snapshot.preview == nil, "\(frame.name) previews a drag")
            #expect(snapshot.inspectedWorld == nil, "\(frame.name) inspects a world")
            #expect(!snapshot.isWon, "\(frame.name) is won")
            #expect(snapshot.time == 0)
            #expect(snapshot.levelNumber == frame.level)
            #expect(snapshot.shownTick == frame.tick, "\(frame.name) shown tick \(snapshot.shownTick)")
            #expect(snapshot.actionsLeft == snapshot.budget - frame.actions.count, "\(frame.name) actions left")
            #expect(snapshot.actionsLeft < snapshot.budget, "\(frame.name) no spent actions bar")
            var finished: BinaryGardensPlay = play
            try finished.apply(.run, expecting: finished.fingerprint)
            #expect(finished.stage == .won, "\(frame.name) the run does not win (\(finished.stage))")
        }
    }

    /// Every frame's description has the frame's identity, size, tick and tilt, the barycentre, one position per
    /// world and per star, every one projecting, the gauge margin, a first actions bar exactly when the budget is
    /// positive and a first tilt pip exactly when the level has a tilt dial (level 25 alone), counts and values that
    /// match the snapshot, the Core's palette and the shaders' material table.
    @Test func everyFrameDescribesItsSnapshot() throws {
        typealias G = BinaryGardensSceneGeometry
        for frame in BinaryGardensGolden.frames {
            let snapshot: BinaryGardensSceneSnapshot = try BinaryGardensGolden.snapshot(frame)
            let description: BinaryGardensGolden.Description = try BinaryGardensGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            #expect(description.tick == snapshot.shownTick)
            #expect(description.tilt == snapshot.arrangement.tilt)
            #expect(description.barycentre != nil, "\(frame.name) barycentre behind the eye")
            #expect(description.gaugeMargin != nil, "\(frame.name) gauge margin behind the eye")
            #expect(description.worlds.count == snapshot.worlds.count, "\(frame.name) world points")
            for point in description.worlds { #expect(point != nil, "\(frame.name) world behind the eye") }
            #expect(description.stars.count == 2, "\(frame.name) star points")
            for point in description.stars { #expect(point != nil, "\(frame.name) star behind the eye") }
            #expect((description.firstActionsBar == nil) == (snapshot.budget <= 0), "\(frame.name) first actions bar")
            let dial: Bool = snapshot.maxTilt > 0
            #expect((description.firstTiltPip != nil) == dial, "\(frame.name) first tilt pip")
            #expect(dial == (frame.level == 25), "\(frame.name) tilt dial (maximum tilt \(snapshot.maxTilt))")
            let counts: BinaryGardensGolden.Counts = description.counts
            #expect(counts.rings == snapshot.ringRadii.count, "\(frame.name) rings")
            var standing: Set<Int> = []
            for ring in snapshot.arrangement.rings { standing.insert(ring) }
            #expect(counts.starRings == standing.count, "\(frame.name) star rings")
            #expect(counts.worlds == snapshot.worlds.count, "\(frame.name) worlds")
            var worldsByBand: [Int] = [0, 0, 0, 0, 0]
            var cellsByBand: [Int] = [0, 0, 0, 0, 0]
            for (index, world) in snapshot.worlds.enumerated() {
                worldsByBand[GoldenSupport.bandIndex(snapshot.band(index))] += 1
                for band in world.bands { cellsByBand[GoldenSupport.bandIndex(band)] += 1 }
            }
            #expect(counts.worldsByBand == worldsByBand, "\(frame.name) worlds by band")
            #expect(counts.cellsByBand == cellsByBand, "\(frame.name) cells by band")
            var cells: Int = 0
            for value in counts.cellsByBand { cells += value }
            #expect(cells == 48 * snapshot.worlds.count, "\(frame.name) cells")
            var short: Int = 0
            for world in snapshot.worlds where world.longestWindow < world.window && world.longestWindow > 0 {
                short += 1
            }
            #expect(counts.shortBrackets == short, "\(frame.name) short brackets")
            #expect(counts.tiltPips == (dial ? snapshot.maxTilt + 1 : 0), "\(frame.name) tilt pips")
            #expect(counts.tiltPipsLit == (dial ? 1 : 0), "\(frame.name) lit tilt pips")
            #expect(counts.luminosityPips == 2 * snapshot.luminosityLevels.count, "\(frame.name) luminosity pips")
            var lit: Int = 0
            for value in snapshot.arrangement.luminosities { lit += value + 1 }
            #expect(counts.luminosityPipsLit == lit, "\(frame.name) lit luminosity pips")
            #expect(counts.actionsLit == G.litActions(snapshot), "\(frame.name) lit actions")
            #expect(counts.actionsLit == snapshot.actionsLeft, "\(frame.name) lit actions against actions left")
            #expect(counts.actions == max(snapshot.budget, 0), "\(frame.name) actions total")
            #expect(counts.actionsLit < counts.actions, "\(frame.name) no spent actions bar")
            #expect(counts.broken == 0, "\(frame.name) an open level draws nothing broken")
            #expect(description.starValues.count == 2, "\(frame.name) star values")
            for star in 0..<min(2, description.starValues.count) {
                let value: BinaryGardensGolden.StarValue = description.starValues[star]
                #expect(value.ring == snapshot.arrangement.rings[star], "\(frame.name) star \(star) ring")
                #expect(value.phase == snapshot.arrangement.phases[star], "\(frame.name) star \(star) phase")
                #expect(value.luminosity == snapshot.arrangement.luminosities[star],
                        "\(frame.name) star \(star) luminosity")
            }
            #expect(description.windows.count == snapshot.worlds.count, "\(frame.name) windows")
            for index in 0..<min(description.windows.count, snapshot.worlds.count) {
                let window: BinaryGardensGolden.WindowValue = description.windows[index]
                let world: BinaryGardensSceneWorld = snapshot.worlds[index]
                #expect(window.integral == world.integral && window.window == world.longestWindow
                        && window.start == world.windowStart, "\(frame.name) world \(index) window")
            }
            #expect(description.colours.count == 27)
            for name in BinaryGardensGolden.colourNames {
                let expected: [Int] = BinaryGardensGolden.colour(BinaryGardensGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
            #expect(description.materials.count == 42, "\(frame.name) materials")
            for (index, entry) in description.materials.enumerated() {
                let material: BinaryGardensMaterial? = BinaryGardensMaterial(rawValue: index)
                #expect(entry.code == index, "\(frame.name) material \(index) code")
                #expect(entry.name == material.map { "\($0)" }, "\(frame.name) material \(index) name")
                #expect(entry.constant == material?.paletteConstant, "\(frame.name) material \(index) constant")
            }
        }
        // Level 25's frame shows its full tilt dial: four pips, the witness's tilt lit.
        let dial: BinaryGardensGolden.Description = try BinaryGardensGolden.describe(
            try GoldenSupport.frame("level-025-tier-0"))
        #expect(dial.counts.tiltPips == 4, "level 25 tilt pips \(dial.counts.tiltPips)")
        #expect(dial.counts.tiltPipsLit == 1)
    }

    /// The tiers of one level share every position, count, value, colour and material; only their identity differs.
    @Test func tiersShareEveryPositionAndCount() throws {
        for level in BinaryGardensGolden.levels {
            var described: [BinaryGardensGolden.Description] = []
            for tier in 0..<3 {
                let name: String = BinaryGardensGolden.name(level: level, tier: tier)
                described.append(try BinaryGardensGolden.describe(try GoldenSupport.frame(name)))
            }
            try #require(described.count == 3)
            for tier in 1..<3 {
                let a: BinaryGardensGolden.Description = described[0]
                let b: BinaryGardensGolden.Description = described[tier]
                #expect(a.barycentre == b.barycentre && a.worlds == b.worlds && a.stars == b.stars
                        && a.gaugeMargin == b.gaugeMargin && a.firstActionsBar == b.firstActionsBar
                        && a.firstTiltPip == b.firstTiltPip, "level \(level) tier \(tier) positions")
                #expect(a.counts == b.counts, "level \(level) tier \(tier) counts")
                #expect(a.tick == b.tick && a.tilt == b.tilt && a.starValues == b.starValues
                        && a.windows == b.windows, "level \(level) tier \(tier) values")
                #expect(a.colours == b.colours && a.materials == b.materials,
                        "level \(level) tier \(tier) colours or materials")
                #expect(b.tier == tier && b.name != a.name, "level \(level) tier \(tier) identity")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run.
    @Test func descriptionsAreDeterministic() throws {
        for frame in BinaryGardensGolden.frames {
            let first: Data = try BinaryGardensGolden.description(frame)
            let second: Data = try BinaryGardensGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try BinaryGardensGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try BinaryGardensGolden.manifest()
        let again: Data = try BinaryGardensGolden.manifest()
        #expect(manifest == again)
    }

    /// Every frame matches the pinned file, which has schema 1, exactly the 17 frame names and equals `manifest()` for
    /// the current code; the file is written only with BINARY_GARDENS_WRITE_GOLDEN=1 (the regeneration hook).
    @Test func everyFrameMatchesThePinnedFile() throws {
        let file: URL = GoldenSupport.file
        let before: Data? = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        if GoldenSupport.writing {
            let written: Bool = try BinaryGardensGolden.writeIfRequested(to: file)
            #expect(written)
            let manifest: Data = try BinaryGardensGolden.manifest()
            let onDisk: Data = try Data(contentsOf: file)
            #expect(onDisk == manifest, "the written file is not BinaryGardensGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            Issue.record("""
                \(file.path) is missing; review the visuals and run with BINARY_GARDENS_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardensRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: file)
        let decoded: BinaryGardensGolden.Manifest = try JSONDecoder().decode(BinaryGardensGolden.Manifest.self,
                                                                             from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == GoldenSupport.expectedNames.sorted())
        let nameProblem: String? = try GoldenSupport.nameProblem(pinned)
        #expect(nameProblem == nil, "\(nameProblem ?? "")")
        let current: BinaryGardensGolden.Manifest = try JSONDecoder().decode(
            BinaryGardensGolden.Manifest.self, from: try BinaryGardensGolden.manifest())
        #expect(current == decoded, "golden-frames.json is not manifest() for the current code")
        for frame in BinaryGardensGolden.frames {
            let result: String? = try BinaryGardensGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
            let entry: BinaryGardensGolden.Entry = try #require(decoded.frames[frame.name])
            let recomputed: Data = try BinaryGardensGolden.description(frame)
            let pinnedDescription: Data = try BinaryGardensGolden.encoder.encode(entry.description)
            #expect(recomputed == pinnedDescription, "\(frame.name) description")
            let digest: String = try BinaryGardensGolden.digest(frame)
            #expect(entry.digest == digest, "\(frame.name) digest")
        }
        if !GoldenSupport.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: file)
            #expect(after == before, "golden-frames.json changed without BINARY_GARDENS_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("binary-gardens-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["BINARY_GARDENS_WRITE_GOLDEN": "0"], ["BINARY_GARDENS_WRITE_GOLDEN": ""],
            ["BINARY_GARDENS_WRITE_GOLDEN": "true"], ["MUSHROOM_WEATHER_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try BinaryGardensGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let existing: Data = Data("an existing file".utf8)
        try existing.write(to: target)
        let refused: Bool = try BinaryGardensGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        let untouched: Data = try Data(contentsOf: target)
        #expect(untouched == existing, "an existing file was touched without the switch")
        let written: Bool = try BinaryGardensGolden.writeIfRequested(
            to: target, environment: ["BINARY_GARDENS_WRITE_GOLDEN": "1"])
        #expect(written)
        let rewritten: Data = try Data(contentsOf: target)
        let manifest: Data = try BinaryGardensGolden.manifest()
        #expect(rewritten == manifest)
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let root: [String: Any] = try GoldenSupport.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in BinaryGardensGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            let recomputed: String = try GoldenSupport.digest(of: description)
            #expect(pinnedDigest == recomputed, "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    /// An unreadable file, schema ≠ 1, a missing, renamed, unknown or extra frame and an identity, size, tick or tilt
    /// change are named.
    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let first: BinaryGardensGolden.Frame = try GoldenSupport.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try BinaryGardensGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try BinaryGardensGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try GoldenSupport.tree(data)
            root["schema"] = value
            let schema: String? = try BinaryGardensGolden.compare(first, pinned: try GoldenSupport.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try GoldenSupport.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try GoldenSupport.bytes(incomplete)
        let missing: String? = try BinaryGardensGolden.compare(try GoldenSupport.frame("level-041-tier-1"),
                                                               pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try BinaryGardensGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")
        let shortenedProblem: String? = try GoldenSupport.nameProblem(shortened)
        #expect(shortenedProblem == "golden-frames.json has no frame level-041-tier-1")

        // A renamed entry: the frame's own name is gone from the file and an unknown name appears.
        var renamedRoot: [String: Any] = try GoldenSupport.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-025-tier-0"])
        renamedFrames.removeValue(forKey: "level-025-tier-0")
        renamedFrames["level-025-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamedData: Data = try GoldenSupport.bytes(renamedRoot)
        let renamed: String? = try BinaryGardensGolden.compare(try GoldenSupport.frame("level-025-tier-0"),
                                                               pinned: renamedData)
        #expect(renamed == "golden-frames.json has no frame level-025-tier-0")
        let renamedProblem: String? = try GoldenSupport.nameProblem(renamedData)
        #expect(renamedProblem == "golden-frames.json has unknown frame level-025-tier-9")

        // An unknown extra entry beside the full set is reported by the name check.
        var extraRoot: [String: Any] = try GoldenSupport.tree(data)
        var extraFrames: [String: Any] = try #require(extraRoot["frames"] as? [String: Any])
        extraFrames["level-099-tier-0"] = try #require(extraFrames["hero"] as? [String: Any])
        extraRoot["frames"] = extraFrames
        let extraData: Data = try GoldenSupport.bytes(extraRoot)
        let extraProblem: String? = try GoldenSupport.nameProblem(extraData)
        #expect(extraProblem == "golden-frames.json has unknown frame level-099-tier-0")

        // A description whose name, level or tier differs from its frame (re-digested) is an identity difference.
        let identity: Data = try GoldenSupport.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try BinaryGardensGolden.compare(
            try GoldenSupport.frame("level-081-tier-0"), pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try BinaryGardensGolden.compare(
                try GoldenSupport.frame("level-021-tier-0"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let sizeKeys: [String] = ["width", "height", "quantum"]
        for key in sizeKeys {
            let size: String? = try BinaryGardensGolden.compare(
                try GoldenSupport.frame("level-021-tier-2"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-2", key: key, by: 1))
            #expect(size == "level-021-tier-2: size differs", "\(key): \(size ?? "nil")")
        }

        // A changed shown tick or tilt is named.
        let tick: String? = try BinaryGardensGolden.compare(
            try GoldenSupport.frame("hero"), pinned: try GoldenSupport.shifted(data, frame: "hero", key: "tick", by: 1))
        #expect(tick?.hasPrefix("hero: tick ") == true, "\(tick ?? "nil")")
        let tilt: String? = try BinaryGardensGolden.compare(
            try GoldenSupport.frame("level-025-tier-0"),
            pinned: try GoldenSupport.shifted(data, frame: "level-025-tier-0", key: "tilt", by: -1))
        #expect(tilt?.hasPrefix("level-025-tier-0: tilt ") == true, "\(tilt ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: BinaryGardensGolden.Frame = BinaryGardensGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [], tick: 24)
        let unknownResult: String? = try BinaryGardensGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// The barycentre, the gauge margin, the first actions bar, the first tilt pip, a world or a star moved by two
    /// quanta fails naming the frame; one quantum passes; a removed world or star point is named as a different number
    /// of points.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let singles: [String] = ["barycentre", "gaugeMargin", "firstActionsBar", "firstTiltPip"]
        let singleWords: [String] = ["barycentre", "gauge margin", "first actions bar", "first tilt pip"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try GoldenSupport.firstPlacedSingle(data, key: key)
            let frame: BinaryGardensGolden.Frame = try GoldenSupport.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }
        // The tilt pip is placed on level 25's frame only.
        let pipFrame: String = try GoldenSupport.firstPlacedSingle(data, key: "firstTiltPip")
        #expect(pipFrame == "level-025-tier-0", "first placed tilt pip on \(pipFrame)")

        let lists: [String] = ["worlds", "stars"]
        let listWords: [String] = ["world", "star"]
        for (keyIndex, key) in lists.enumerated() {
            let placed: (frame: String, index: Int) = try #require(
                try GoldenSupport.firstPlacedListPoint(data, key: key), "no frame has a \(key) position")
            let name: String = placed.frame
            let index: Int = placed.index
            let frame: BinaryGardensGolden.Frame = try GoldenSupport.frame(name)
            let word: String = listWords[keyIndex]

            let far: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.movedListPoint(data, frame: name, key: key, index: index, dx: 2))
            #expect(far?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(far ?? "nil")")

            let farY: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.movedListPoint(data, frame: name, key: key, index: index, dy: -2))
            #expect(farY?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(farY ?? "nil")")

            let near: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.movedListPoint(data, frame: name, key: key, index: index, dx: 1,
                                                                dy: 1))
            #expect(near == nil, "\(key): \(near ?? "")")

            let fewer: Data = try GoldenSupport.edited(data, frame: name) { description in
                var points: [Any] = try #require(description[key] as? [Any])
                points.removeLast()
                description[key] = points
            }
            let fewerResult: String? = try BinaryGardensGolden.compare(frame, pinned: fewer)
            #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(key): \(fewerResult ?? "nil")")
            #expect(fewerResult?.contains("\(word) points, pinned") == true, "\(key): \(fewerResult ?? "nil")")
        }
    }

    /// A changed colour, count (naming it), star value, world window or material entry fails naming the frame.
    @Test func colourCountValueAndMaterialChangesAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: BinaryGardensGolden.Frame = try GoldenSupport.frame(name)

        for colourName in BinaryGardensGolden.colourNames {
            let palette: Data = try GoldenSupport.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [Int] = try #require(colours[colourName] as? [Int])
                try #require(colour.count == 3)
                colour[1] = colour[1] == 255 ? 254 : colour[1] + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try BinaryGardensGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        for key in GoldenSupport.scalarCountKeys {
            let counts: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.shiftedCount(data, frame: name, key: key, by: 1))
            #expect(counts?.hasPrefix("\(name): count \(key) ") == true, "\(key): \(counts ?? "nil")")
        }
        for key in GoldenSupport.bandCountKeys {
            for band in 0..<5 {
                let counts: String? = try BinaryGardensGolden.compare(
                    frame, pinned: try GoldenSupport.shiftedBandCount(data, frame: name, key: key, index: band,
                                                                      by: 1))
                #expect(counts?.hasPrefix("\(name): count \(key) ") == true, "\(key)[\(band)]: \(counts ?? "nil")")
            }
        }

        let starFields: [String] = ["ring", "phase", "luminosity"]
        for star in 0..<2 {
            for field in starFields {
                let result: String? = try BinaryGardensGolden.compare(
                    frame, pinned: try GoldenSupport.shiftedListField(data, frame: name, key: "starValues",
                                                                      index: star, field: field, by: 1))
                #expect(result?.hasPrefix("\(name): star \(star) ring ") == true,
                        "star \(star) \(field): \(result ?? "nil")")
            }
        }

        let windowFields: [String] = ["integral", "window", "start"]
        for field in windowFields {
            let result: String? = try BinaryGardensGolden.compare(
                frame, pinned: try GoldenSupport.shiftedListField(data, frame: name, key: "windows", index: 0,
                                                                  field: field, by: 1))
            #expect(result?.hasPrefix("\(name): world 0 integral ") == true, "window \(field): \(result ?? "nil")")
        }

        // A material entry with another code, name or constant, an added entry and a removed entry are named.
        let shiftedCode: String? = try BinaryGardensGolden.compare(
            frame, pinned: try GoldenSupport.shiftedListField(data, frame: name, key: "materials", index: 17,
                                                              field: "code", by: 1))
        #expect(shiftedCode?.hasPrefix("\(name): material 17 is ") == true, "\(shiftedCode ?? "nil")")
        let textFields: [String] = ["name", "constant"]
        for field in textFields {
            let changed: Data = try GoldenSupport.edited(data, frame: name) { description in
                var list: [Any] = try #require(description["materials"] as? [Any])
                var item: [String: Any] = try #require(list[41] as? [String: Any])
                item[field] = "BG_CHANGED"
                list[41] = item
                description["materials"] = list
            }
            let result: String? = try BinaryGardensGolden.compare(frame, pinned: changed)
            #expect(result?.hasPrefix("\(name): material 41 is ") == true, "material \(field): \(result ?? "nil")")
        }
        let added: Data = try GoldenSupport.edited(data, frame: name) { description in
            var list: [Any] = try #require(description["materials"] as? [Any])
            let extra: [String: Any] = ["code": 42, "name": "extra", "constant": "BG_MARKER"]
            list.append(extra)
            description["materials"] = list
        }
        let addedResult: String? = try BinaryGardensGolden.compare(frame, pinned: added)
        #expect(addedResult == "\(name): 42 materials, pinned 43", "\(addedResult ?? "nil")")
        let removed: Data = try GoldenSupport.edited(data, frame: name) { description in
            var list: [Any] = try #require(description["materials"] as? [Any])
            list.removeLast()
            description["materials"] = list
        }
        let removedResult: String? = try BinaryGardensGolden.compare(frame, pinned: removed)
        #expect(removedResult == "\(name): 42 materials, pinned 41", "\(removedResult ?? "nil")")
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let edited: Data = try GoldenSupport.edited(data, frame: "hero", redigest: false) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            counts["actions"] = 99
            description["counts"] = counts
        }
        let message: String? = try BinaryGardensGolden.compare(try GoldenSupport.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try GoldenSupport.edited(data, frame: "level-025-tier-0", redigest: false) { description in
            if let point = description["firstTiltPip"] as? [Int], point.count == 2 {
                description["firstTiltPip"] = [point[0] + 1, point[1]]
            } else {
                description["firstTiltPip"] = [0, 0]
            }
        }
        let movedMessage: String? = try BinaryGardensGolden.compare(
            try GoldenSupport.frame("level-025-tier-0"), pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-025-tier-0: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
