// MicroscopicAuroraRegressionGoldenTests — feature 488 (R02-G19-08) T-R02G1908-004 (FR-R02G1908-003, 004;
// SC-R02G1908-003; clarification Q3; research R2, R3, R6). The code-only visual baseline of Microscopic Aurora: the
// fixed golden set of 16 frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0, each after all of the stored
// witness's placements — `docs/games/microscopic-aurora/levels/NNN.witness.json` without its final play — but not the
// play, shown at the tick half the ticks swum, `ticksSwum / 2` as the feature-483 frame checks; then the hero frame:
// the level the hero scenario opens, seed `manifestSeed`, after the same placements with the hero tick shown, tier 0)
// in its fixed order with unique names; every frame is still open, its actions bars are partly spent and the play then
// wins it; every frame's counts match the snapshot and the tier's ribbons and its palette (18 colours) is the Core's;
// deterministic descriptions and digests; every frame's recomputed description against the pinned file
// MicroscopicAurora/golden-frames.json, which holds exactly the 16 frame names under schema 1 and equals `manifest()`
// for the current code; every pinned digest against the digest of its pinned description; and the failures the
// comparison must name, built from the pinned manifest in memory (the pinned file is never written by them): the dish
// centre, a swimmer, a placed well, a site or the first actions bar moved by two 1/8-pixel quanta fails naming the
// frame while one quantum passes, a changed palette colour, a changed count, a changed identity, size or tick, a
// missing frame, a renamed or unknown frame, an unknown extra entry in the file (checked by name equality, as
// `compare` looks up one frame at a time), a schema other than 1, an unreadable file and a hand-edited description that
// kept its old digest. A position may be null in the schema (a point behind the eye); the helpers that pick a position
// to move skip nulls. `writeIfRequested` is exercised on a temporary file only: it writes nothing without the switch
// and exactly the manifest with it.
//
// The pinned file is written only when MICROSCOPIC_AURORA_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     MICROSCOPIC_AURORA_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter MicroscopicAuroraRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule), and no `try` inside
// `#expect`. Synthetic data only; no wall-clock asserts. Modelled on ApsidesWorkshopRegressionGoldenTests
// (feature 478).
import Foundation
import Testing
import VisualCoreMath
@testable import MicroscopicAuroraCore

/// File-private helpers of the golden tests, kept in one namespace so no name collides with other files of the target.
private enum GoldenSupport {
    /// The pinned golden file, found from this file (…/MicroscopicAurora/CoreTests/ → ../golden-frames.json).
    static let file: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("golden-frames.json", isDirectory: false)

    /// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[MicroscopicAuroraGolden.writeSwitch] == "1"
    }

    /// The 16 frame names in their fixed order.
    static let expectedNames: [String] = [
        "level-001-tier-0", "level-001-tier-1", "level-001-tier-2",
        "level-021-tier-0", "level-021-tier-1", "level-021-tier-2",
        "level-041-tier-0", "level-041-tier-1", "level-041-tier-2",
        "level-061-tier-0", "level-061-tier-1", "level-061-tier-2",
        "level-081-tier-0", "level-081-tier-1", "level-081-tier-2",
        "hero",
    ]

    /// The 18 described palette colours in the order the comparison checks them.
    static let colourNames: [String] = [
        "abyss", "abyssTop", "field", "frond", "rim", "stencil", "lit", "stray", "site", "well", "ribbon", "swimmer",
        "met", "unmet", "actionsLit", "actionsUnlit", "broken", "glow",
    ]

    /// The stored witness's placements of level `number`: its actions, which end with the play, without the play.
    static func witnessPlacements(_ number: Int) throws -> [MicroscopicAuroraAction] {
        let name: String = String(MicroscopicAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        let witness: MicroscopicAuroraWitness = try JSONDecoder().decode(MicroscopicAuroraWitness.self, from: data)
        #expect(witness.actions.last == .play, "witness \(number) does not end with the play")
        var placements: [MicroscopicAuroraAction] = []
        for action in witness.actions where action != .play { placements.append(action) }
        return placements
    }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: file.path) { return try Data(contentsOf: file) }
        return try MicroscopicAuroraGolden.manifest()
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
        let decoded: MicroscopicAuroraGolden.Description = try JSONDecoder().decode(
            MicroscopicAuroraGolden.Description.self, from: data)
        return try MicroscopicAuroraGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in MicroscopicAuroraGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with the count `key` of `frame`'s description shifted by `delta`.
    static func shiftedCount(_ data: Data, frame: String, key: String, by delta: Int) throws -> Data {
        try edited(data, frame: frame) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            let value: Int = try #require(counts[key] as? Int)
            counts[key] = value + delta
            description["counts"] = counts
        }
    }

    /// `point` (a JSON position `[x, y]`) moved by `dx`, `dy` quanta.
    static func movedPoint(_ point: Any?, dx: Int, dy: Int) throws -> [Int] {
        let position: [Int] = try #require(point as? [Int])
        try #require(position.count == 2)
        return [position[0] + dx, position[1] + dy]
    }

    /// The manifest `data` with position `index` (0-based) of the list `key` (`swimmers`, `wells`, `sites`) of
    /// `frame`'s description moved by `dx`, `dy` quanta.
    static func movedInList(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0,
                            dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// The manifest `data` with the single position `key` (`dish`, `firstActionsBar`) of `frame` moved by `dx`, `dy`
    /// quanta.
    static func movedSingle(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// A pinned position of the list `key`: the first golden frame (in the fixed order) whose pinned description has
    /// one that projects (not null), and the 0-based index of that position; nil when no frame has one.
    static func firstPlacedInList(_ data: Data, key: String) throws -> (frame: String, index: Int)? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in MicroscopicAuroraGolden.frames {
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
        for golden in MicroscopicAuroraGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> MicroscopicAuroraGolden.Frame {
        for frame in MicroscopicAuroraGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The number of placed wells of `snapshot`.
    static func placedWells(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Int {
        var count: Int = 0
        for well in snapshot.wells where well != nil { count += 1 }
        return count
    }

    /// The number of met gauges of `snapshot` (the frame is never won).
    static func metCount(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Int {
        var count: Int = 0
        if snapshot.coverage >= snapshot.requiredCoverage { count += 1 }
        if snapshot.coherence >= snapshot.requiredCoherence { count += 1 }
        return count
    }

    /// The ribbon points of every swimmer of `snapshot` at `tier`: per swimmer the ticks max(0, shown − L) … shown.
    static func ribbonPoints(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier) -> Int {
        let head: Int = snapshot.shownTick
        let tail: Int = max(0, head - tier.ribbonTicks)
        return snapshot.positions.count * (head - tail + 1)
    }
}

/// The code-only golden frames of Microscopic Aurora against the pinned file (see the file header).
@Suite struct MicroscopicAuroraRegressionGoldenTests {
    /// The 16 frames, their order, unique names, levels, tiers, time, placements and ticks; each level frame applies
    /// all of its stored witness's placements (never the play) at the tick half the ticks swum; the hero frame applies
    /// the hero level's placements and shows the hero tick.
    @Test func theGoldenSetIsFixed() throws {
        typealias Core = MicroscopicAuroraExperienceCore
        let frames: [MicroscopicAuroraGolden.Frame] = MicroscopicAuroraGolden.frames
        #expect(frames.count == 16)
        var actualNames: [String] = []
        var names: Set<String> = []
        for frame in frames {
            actualNames.append(frame.name)
            names.insert(frame.name)
        }
        #expect(names.count == 16)
        #expect(actualNames == GoldenSupport.expectedNames)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(MicroscopicAuroraGolden.levels == levels)
        #expect(MicroscopicAuroraGolden.width == 1_152)
        #expect(MicroscopicAuroraGolden.height == 768)
        #expect(MicroscopicAuroraGolden.schema == 1)
        #expect(MicroscopicAuroraGolden.quantum == 8)
        #expect(MicroscopicAuroraGolden.time == 0)
        #expect(MicroscopicAuroraGolden.writeSwitch == "MICROSCOPIC_AURORA_WRITE_GOLDEN")
        #expect(MicroscopicAuroraGolden.colourNames == GoldenSupport.colourNames)
        try #require(frames.count == 16)
        var index: Int = 0
        for level in levels {
            let placements: [MicroscopicAuroraAction] = try GoldenSupport.witnessPlacements(level)
            #expect(!placements.isEmpty, "level \(level) witness has no placement")
            #expect(Core.certifiedActions(level) == placements, "level \(level) certified plan is not the witness's")
            let opening: MicroscopicAuroraExperienceCore = try Core.opening(number: level)
            var play: MicroscopicAuroraPlay = opening.play
            for action in placements { try play.apply(action, expecting: play.fingerprint) }
            let half: Int = play.report.ticks / 2
            for tier in 0..<3 {
                let frame: MicroscopicAuroraGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.tick == half, "\(frame.name) tick \(frame.tick), half \(half)")
                #expect(frame.name == MicroscopicAuroraGolden.name(level: level, tier: tier))
                #expect(frame.actions == placements, "\(frame.name) actions")
                #expect(!frame.actions.contains(.play), "\(frame.name) applies the play")
                index += 1
            }
        }
        let hero: MicroscopicAuroraGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        let heroPlacements: [MicroscopicAuroraAction] = try GoldenSupport.witnessPlacements(heroLevel)
        #expect(hero.actions == heroPlacements)
        #expect(!hero.actions.contains(.play), "hero applies the play")
        let heroTick: Int = try #require(Core.heroTick(heroLevel))
        #expect(hero.tick == heroTick, "hero tick \(hero.tick)")
        // The hero scenario is the placements, then one shown tick.
        #expect(Core.heroEntries.count == hero.actions.count + 1)
    }

    /// The shown tick is 0 and no placement is applied for a level that cannot be generated.
    @Test func aLevelOutsideTheCatalogShowsTickZero() {
        let outside: [Int] = [0, 101]
        for number in outside {
            let tick: Int = MicroscopicAuroraGolden.shownTick(number)
            #expect(tick == 0, "level \(number) tick \(tick)")
            #expect(MicroscopicAuroraGolden.openPlacements(number).isEmpty, "level \(number) applies a placement")
        }
    }

    /// Every frame is still open: stage `playing`, no failure, not won, no preview, not frozen, the actions bars partly
    /// spent, the shown tick half the ticks swum (the hero tick for the hero) and the play then wins it.
    @Test func everyFrameIsOpenAndThePlayWinsIt() throws {
        for frame in MicroscopicAuroraGolden.frames {
            let level: MicroscopicAuroraLevel = try MicroscopicAuroraExperienceCore.level(number: frame.level)
            var play: MicroscopicAuroraPlay = try MicroscopicAuroraExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: MicroscopicAuroraSceneSnapshot = try MicroscopicAuroraGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) predicts a failure")
            #expect(snapshot.preview == nil, "\(frame.name) previews a well")
            #expect(!snapshot.frozen, "\(frame.name) is frozen")
            #expect(snapshot.time == 0)
            #expect(snapshot.levelNumber == frame.level)
            #expect(snapshot.shownTick == frame.tick, "\(frame.name) shown tick \(snapshot.shownTick)")
            if frame.name == "hero" {
                #expect(snapshot.shownTick == snapshot.ticksSwum, "hero shows tick \(snapshot.shownTick)")
            } else {
                #expect(snapshot.shownTick == snapshot.ticksSwum / 2, "\(frame.name) half tick")
            }
            #expect(snapshot.actionsLeft < snapshot.budget, "\(frame.name) no spent actions bar")
            var finished: MicroscopicAuroraPlay = play
            try finished.apply(.play, expecting: finished.fingerprint)
            #expect(finished.stage == .won, "\(frame.name) the play does not win (\(finished.stage))")
        }
    }

    /// Every frame's description has the frame's identity, size and tick, the dish centre, one position per swimmer,
    /// placed well and site, every swimmer, well and site projecting, a first actions bar exactly when the budget is
    /// positive, counts that match the snapshot and the tier's ribbons, and the Core's palette.
    @Test func everyFrameDescribesItsSnapshot() throws {
        typealias G = MicroscopicAuroraSceneGeometry
        for frame in MicroscopicAuroraGolden.frames {
            let snapshot: MicroscopicAuroraSceneSnapshot = try MicroscopicAuroraGolden.snapshot(frame)
            let tier: MicroscopicAuroraTier = MicroscopicAuroraTier.of(frame.tier)
            let description: MicroscopicAuroraGolden.Description = try MicroscopicAuroraGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            #expect(description.tick == snapshot.shownTick)
            #expect(description.dish != nil, "\(frame.name) dish centre behind the eye")
            #expect(description.swimmers.count == snapshot.positions.count, "\(frame.name) swimmer points")
            #expect(description.wells.count == GoldenSupport.placedWells(snapshot), "\(frame.name) well points")
            #expect(description.sites.count == snapshot.sites.count, "\(frame.name) site points")
            for point in description.swimmers { #expect(point != nil, "\(frame.name) swimmer behind the eye") }
            for point in description.wells { #expect(point != nil, "\(frame.name) well behind the eye") }
            for point in description.sites { #expect(point != nil, "\(frame.name) site behind the eye") }
            #expect((description.firstActionsBar == nil) == (snapshot.budget <= 0), "\(frame.name) first actions bar")
            let counts: MicroscopicAuroraGolden.Counts = description.counts
            #expect(counts.stencil == snapshot.stencil.count, "\(frame.name) stencil")
            #expect(counts.lit == snapshot.litStencil.count, "\(frame.name) lit")
            #expect(counts.lit <= counts.stencil, "\(frame.name) lit beyond stencil")
            #expect(counts.stray == snapshot.stray.count, "\(frame.name) stray")
            #expect(counts.sites == snapshot.sites.count, "\(frame.name) sites")
            #expect(counts.wells == GoldenSupport.placedWells(snapshot), "\(frame.name) wells")
            #expect(counts.wells == frame.actions.count, "\(frame.name) wells against placements")
            #expect(counts.swimmers == snapshot.swarm, "\(frame.name) swimmers")
            #expect(counts.ribbonPoints == GoldenSupport.ribbonPoints(snapshot, tier: tier),
                    "\(frame.name) ribbon points \(counts.ribbonPoints)")
            #expect(counts.gauges == 2, "\(frame.name) gauges")
            #expect(counts.met == GoldenSupport.metCount(snapshot), "\(frame.name) met")
            #expect(counts.litActions == G.litActions(snapshot), "\(frame.name) lit actions")
            #expect(counts.litActions == snapshot.actionsLeft, "\(frame.name) lit actions against actions left")
            #expect(counts.actions == max(snapshot.budget, 0), "\(frame.name) actions total")
            #expect(counts.litActions < counts.actions, "\(frame.name) no spent actions bar")
            #expect(description.colours.count == 18)
            for name in MicroscopicAuroraGolden.colourNames {
                let expected: MicroscopicAuroraGolden.Colour = MicroscopicAuroraGolden.colour(
                    MicroscopicAuroraGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
        }
    }

    /// The tiers of one level share every position and count but the ribbon points, which never grow from tier 0 to
    /// tier 2.
    @Test func tiersDifferOnlyInRibbonPoints() throws {
        for level in MicroscopicAuroraGolden.levels {
            var described: [MicroscopicAuroraGolden.Description] = []
            for tier in 0..<3 {
                let name: String = MicroscopicAuroraGolden.name(level: level, tier: tier)
                described.append(try MicroscopicAuroraGolden.describe(try GoldenSupport.frame(name)))
            }
            try #require(described.count == 3)
            for tier in 1..<3 {
                let a: MicroscopicAuroraGolden.Description = described[0]
                let b: MicroscopicAuroraGolden.Description = described[tier]
                #expect(a.dish == b.dish && a.swimmers == b.swimmers && a.wells == b.wells && a.sites == b.sites
                        && a.firstActionsBar == b.firstActionsBar, "level \(level) tier \(tier) positions")
                #expect(a.counts.stencil == b.counts.stencil && a.counts.lit == b.counts.lit
                        && a.counts.stray == b.counts.stray && a.counts.met == b.counts.met
                        && a.counts.litActions == b.counts.litActions, "level \(level) tier \(tier) counts")
                #expect(b.counts.ribbonPoints <= described[tier - 1].counts.ribbonPoints,
                        "level \(level) tier \(tier) ribbon points grow")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run.
    @Test func descriptionsAreDeterministic() throws {
        for frame in MicroscopicAuroraGolden.frames {
            let first: Data = try MicroscopicAuroraGolden.description(frame)
            let second: Data = try MicroscopicAuroraGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try MicroscopicAuroraGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try MicroscopicAuroraGolden.manifest()
        let again: Data = try MicroscopicAuroraGolden.manifest()
        #expect(manifest == again)
    }

    /// Every frame matches the pinned file, which has schema 1, exactly the 16 frame names and equals `manifest()` for
    /// the current code; the file is written only with MICROSCOPIC_AURORA_WRITE_GOLDEN=1 (the regeneration hook).
    @Test func everyFrameMatchesThePinnedFile() throws {
        let file: URL = GoldenSupport.file
        let before: Data? = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        if GoldenSupport.writing {
            let written: Bool = try MicroscopicAuroraGolden.writeIfRequested(to: file)
            #expect(written)
            let manifest: Data = try MicroscopicAuroraGolden.manifest()
            let onDisk: Data = try Data(contentsOf: file)
            #expect(onDisk == manifest, "the written file is not MicroscopicAuroraGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            Issue.record("""
                \(file.path) is missing; review the visuals and run with MICROSCOPIC_AURORA_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter MicroscopicAuroraRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: file)
        let decoded: MicroscopicAuroraGolden.Manifest = try JSONDecoder().decode(
            MicroscopicAuroraGolden.Manifest.self, from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == GoldenSupport.expectedNames.sorted())
        let nameProblem: String? = try GoldenSupport.nameProblem(pinned)
        #expect(nameProblem == nil, "\(nameProblem ?? "")")
        let current: MicroscopicAuroraGolden.Manifest = try JSONDecoder().decode(
            MicroscopicAuroraGolden.Manifest.self, from: try MicroscopicAuroraGolden.manifest())
        #expect(current == decoded, "golden-frames.json is not manifest() for the current code")
        for frame in MicroscopicAuroraGolden.frames {
            let result: String? = try MicroscopicAuroraGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
            let entry: MicroscopicAuroraGolden.Entry = try #require(decoded.frames[frame.name])
            let recomputed: Data = try MicroscopicAuroraGolden.description(frame)
            let pinnedDescription: Data = try MicroscopicAuroraGolden.encoder.encode(entry.description)
            #expect(recomputed == pinnedDescription, "\(frame.name) description")
            let digest: String = try MicroscopicAuroraGolden.digest(frame)
            #expect(entry.digest == digest, "\(frame.name) digest")
        }
        if !GoldenSupport.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: file)
            #expect(after == before, "golden-frames.json changed without MICROSCOPIC_AURORA_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("microscopic-aurora-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["MICROSCOPIC_AURORA_WRITE_GOLDEN": "0"], ["MICROSCOPIC_AURORA_WRITE_GOLDEN": ""],
            ["MICROSCOPIC_AURORA_WRITE_GOLDEN": "true"], ["APSIDES_WORKSHOP_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try MicroscopicAuroraGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let placeholder: Data = Data("placeholder".utf8)
        try placeholder.write(to: target)
        let refused: Bool = try MicroscopicAuroraGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        let untouched: Data = try Data(contentsOf: target)
        #expect(untouched == placeholder, "an existing file was touched without the switch")
        let written: Bool = try MicroscopicAuroraGolden.writeIfRequested(
            to: target, environment: ["MICROSCOPIC_AURORA_WRITE_GOLDEN": "1"])
        #expect(written)
        let rewritten: Data = try Data(contentsOf: target)
        let manifest: Data = try MicroscopicAuroraGolden.manifest()
        #expect(rewritten == manifest)
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let root: [String: Any] = try GoldenSupport.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in MicroscopicAuroraGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            let recomputed: String = try GoldenSupport.digest(of: description)
            #expect(pinnedDigest == recomputed, "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    /// An unreadable file, schema ≠ 1, a missing, renamed, unknown or extra frame and an identity, size or tick change
    /// are named.
    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let first: MicroscopicAuroraGolden.Frame = try GoldenSupport.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try MicroscopicAuroraGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try MicroscopicAuroraGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try GoldenSupport.tree(data)
            root["schema"] = value
            let schema: String? = try MicroscopicAuroraGolden.compare(first, pinned: try GoldenSupport.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try GoldenSupport.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try GoldenSupport.bytes(incomplete)
        let missing: String? = try MicroscopicAuroraGolden.compare(try GoldenSupport.frame("level-041-tier-1"),
                                                                   pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try MicroscopicAuroraGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")
        let shortenedProblem: String? = try GoldenSupport.nameProblem(shortened)
        #expect(shortenedProblem == "golden-frames.json has no frame level-041-tier-1")

        // A renamed entry: the frame's own name is gone from the file and an unknown name appears.
        var renamedRoot: [String: Any] = try GoldenSupport.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamedData: Data = try GoldenSupport.bytes(renamedRoot)
        let renamed: String? = try MicroscopicAuroraGolden.compare(try GoldenSupport.frame("level-061-tier-2"),
                                                                   pinned: renamedData)
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")
        let renamedProblem: String? = try GoldenSupport.nameProblem(renamedData)
        #expect(renamedProblem == "golden-frames.json has unknown frame level-061-tier-9")

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
        let identityResult: String? = try MicroscopicAuroraGolden.compare(
            try GoldenSupport.frame("level-081-tier-0"), pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try MicroscopicAuroraGolden.compare(
                try GoldenSupport.frame("level-021-tier-0"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let sizeKeys: [String] = ["width", "height", "quantum"]
        for key in sizeKeys {
            let size: String? = try MicroscopicAuroraGolden.compare(
                try GoldenSupport.frame("level-021-tier-2"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-2", key: key, by: 1))
            #expect(size == "level-021-tier-2: size differs", "\(key): \(size ?? "nil")")
        }

        // A changed shown tick is named.
        let tick: String? = try MicroscopicAuroraGolden.compare(
            try GoldenSupport.frame("hero"), pinned: try GoldenSupport.shifted(data, frame: "hero", key: "tick", by: 1))
        #expect(tick?.hasPrefix("hero: tick ") == true, "\(tick ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: MicroscopicAuroraGolden.Frame = MicroscopicAuroraGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [], tick: 0)
        let unknownResult: String? = try MicroscopicAuroraGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// The dish centre, a swimmer, a placed well, a site or the first actions bar moved by two quanta fails naming the
    /// frame; one quantum passes; a removed list position is named as a different number of points.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let singles: [String] = ["dish", "firstActionsBar"]
        let singleWords: [String] = ["dish centre", "first actions bar"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try GoldenSupport.firstPlacedSingle(data, key: key)
            let frame: MicroscopicAuroraGolden.Frame = try GoldenSupport.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try MicroscopicAuroraGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try MicroscopicAuroraGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try MicroscopicAuroraGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }

        let lists: [String] = ["swimmers", "wells", "sites"]
        let listWords: [String] = ["swimmer", "well", "site"]
        for (keyIndex, key) in lists.enumerated() {
            let placed: (frame: String, index: Int) = try #require(try GoldenSupport.firstPlacedInList(data, key: key),
                                                                   "no frame has a \(key) position")
            let name: String = placed.frame
            let index: Int = placed.index
            let word: String = listWords[keyIndex]
            let frame: MicroscopicAuroraGolden.Frame = try GoldenSupport.frame(name)

            let far: String? = try MicroscopicAuroraGolden.compare(
                frame, pinned: try GoldenSupport.movedInList(data, frame: name, key: key, index: index, dx: 2))
            #expect(far?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(far ?? "nil")")

            let farY: String? = try MicroscopicAuroraGolden.compare(
                frame, pinned: try GoldenSupport.movedInList(data, frame: name, key: key, index: index, dy: -2))
            #expect(farY?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(farY ?? "nil")")

            let near: String? = try MicroscopicAuroraGolden.compare(
                frame, pinned: try GoldenSupport.movedInList(data, frame: name, key: key, index: index, dx: 1, dy: 1))
            #expect(near == nil, "\(key): \(near ?? "")")

            let fewer: Data = try GoldenSupport.edited(data, frame: name) { description in
                var points: [Any] = try #require(description[key] as? [Any])
                points.removeLast()
                description[key] = points
            }
            let fewerResult: String? = try MicroscopicAuroraGolden.compare(frame, pinned: fewer)
            #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(key): \(fewerResult ?? "nil")")
            #expect(fewerResult?.contains("\(word) points, pinned") == true, "\(key): \(fewerResult ?? "nil")")
        }
    }

    /// A changed colour or count fails naming the frame.
    @Test func colourAndCountChangesAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: MicroscopicAuroraGolden.Frame = try GoldenSupport.frame(name)

        for colourName in MicroscopicAuroraGolden.colourNames {
            let palette: Data = try GoldenSupport.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try MicroscopicAuroraGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = [
            "stencil", "lit", "stray", "sites", "wells", "swimmers", "ribbonPoints", "gauges", "met", "litActions",
            "actions",
        ]
        for key in countKeys {
            let counts: String? = try MicroscopicAuroraGolden.compare(
                frame, pinned: try GoldenSupport.shiftedCount(data, frame: name, key: key, by: 1))
            #expect(counts?.hasPrefix("\(name): counts differ") == true, "\(key): \(counts ?? "nil")")
        }
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let edited: Data = try GoldenSupport.edited(data, frame: "hero", redigest: false) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            counts["actions"] = 99
            description["counts"] = counts
        }
        let message: String? = try MicroscopicAuroraGolden.compare(try GoldenSupport.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try GoldenSupport.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            if let point = description["dish"] as? [Int], point.count == 2 {
                description["dish"] = [point[0] + 1, point[1]]
            } else {
                description["dish"] = [0, 0]
            }
        }
        let movedMessage: String? = try MicroscopicAuroraGolden.compare(
            try GoldenSupport.frame("level-021-tier-1"), pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
