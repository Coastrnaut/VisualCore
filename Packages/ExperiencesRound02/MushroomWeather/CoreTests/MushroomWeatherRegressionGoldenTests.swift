// MushroomWeatherRegressionGoldenTests — feature 498 (R02-G20-08) T-R02G2008-004 (FR-R02G2008-003, 004;
// SC-R02G2008-003; clarification Q3). The code-only visual baseline of Mushroom Weather: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0, each after all of the stored witness's arrangement
// actions — `docs/games/mushroom-weather/levels/NNN.witness.json` without its final run — but not the run, shown at the
// cycle half the cycles run, `cyclesRun / 2` as the feature-493 frame checks; then the hero frame: the level the hero
// scenario opens, seed `manifestSeed`, after the same actions with the hero cycle shown, tier 0) in its fixed order with
// unique names; every frame is still open, its actions bars are partly spent and the run then wins it; every frame's
// counts match the snapshot and its palette (21 colours) is the Core's; the tiers of a level share every position and
// count; deterministic descriptions and digests; every frame's recomputed description against the pinned file
// MushroomWeather/golden-frames.json, which holds exactly the 16 frame names under schema 1 and equals `manifest()` for
// the current code; every pinned digest against the digest of its pinned description; and the failures the comparison
// must name, built from the pinned manifest in memory (the pinned file is never written by them): the floor centre, a
// cap, the moon centre, the first gauge track or the first actions bar moved by two 1/8-pixel quanta fails naming the
// frame while one quantum passes, a changed palette colour, a changed count or moonlight, a changed identity, size or
// cycle, a missing frame, a renamed or unknown frame, an unknown extra entry in the file (checked by name equality, as
// `compare` looks up one frame at a time), a schema other than 1, an unreadable file and a hand-edited description that
// kept its old digest. A position may be null in the schema (a point behind the eye); the helpers that pick a position
// to move skip nulls. `writeIfRequested` is exercised on a temporary file only: it writes nothing without the switch and
// exactly the manifest with it.
//
// The pinned file is written only when MUSHROOM_WEATHER_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     MUSHROOM_WEATHER_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter MushroomWeatherRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule), and no `try` inside
// `#expect`. Synthetic data only; no wall-clock asserts. Modelled on MicroscopicAuroraRegressionGoldenTests
// (feature 488).
import Foundation
import Testing
import VisualCoreMath
@testable import MushroomWeatherCore

/// File-private helpers of the golden tests, kept in one namespace so no name collides with other files of the target.
private enum GoldenSupport {
    /// The pinned golden file, found from this file (…/MushroomWeather/CoreTests/ → ../golden-frames.json).
    static let file: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("golden-frames.json", isDirectory: false)

    /// The repository's witness directory, found from this file (five levels up: CoreTests, MushroomWeather, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/mushroom-weather/levels", isDirectory: true)

    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[MushroomWeatherGolden.writeSwitch] == "1"
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

    /// The 21 described palette colours in declaration order.
    static let colourNames: [String] = [
        "midnight", "midnightTop", "moon", "moss", "log", "frond", "mistLow", "mistHigh", "site", "stalk", "cap",
        "capOut", "pod", "droplet", "vent", "band", "marker", "actionsLit", "actionsUnlit", "broken", "glow",
    ]

    /// The stored witness's arrangement actions of level `number`: its actions, which end with the run, without the
    /// run.
    static func witnessChanges(_ number: Int) throws -> [MushroomWeatherAction] {
        let name: String = String(MushroomWeatherGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        let witness: MushroomWeatherWitness = try JSONDecoder().decode(MushroomWeatherWitness.self, from: data)
        #expect(witness.actions.last == .run, "witness \(number) does not end with the run")
        var changes: [MushroomWeatherAction] = []
        for action in witness.actions where action != .run { changes.append(action) }
        return changes
    }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: file.path) { return try Data(contentsOf: file) }
        return try MushroomWeatherGolden.manifest()
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
        let decoded: MushroomWeatherGolden.Description = try JSONDecoder().decode(
            MushroomWeatherGolden.Description.self, from: data)
        return try MushroomWeatherGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in MushroomWeatherGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with cap position `index` (0-based) of `frame`'s description moved by `dx`, `dy` quanta.
    static func movedCap(_ data: Data, frame: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description["caps"] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description["caps"] = points
        }
    }

    /// The manifest `data` with the single position `key` (`floor`, `moon`, `firstGaugeTrack`, `firstActionsBar`) of
    /// `frame` moved by `dx`, `dy` quanta.
    static func movedSingle(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// A pinned cap position: the first golden frame (in the fixed order) whose pinned description has one that
    /// projects (not null), and the 0-based index of that position; nil when no frame has one.
    static func firstPlacedCap(_ data: Data) throws -> (frame: String, index: Int)? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in MushroomWeatherGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description["caps"] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        return nil
    }

    /// The first golden frame (in the fixed order) whose pinned description has the single position `key` (not null).
    static func firstPlacedSingle(_ data: Data, key: String) throws -> String {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in MushroomWeatherGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> MushroomWeatherGolden.Frame {
        for frame in MushroomWeatherGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The number of placed pods of `snapshot`.
    static func placedPods(_ snapshot: MushroomWeatherSceneSnapshot) -> Int {
        var count: Int = 0
        for pod in snapshot.pods where pod != nil { count += 1 }
        return count
    }

    /// The number of pods of `snapshot` grown by the shown cycle (their growth cycle at or before it).
    static func grownPods(_ snapshot: MushroomWeatherSceneSnapshot) -> Int {
        var count: Int = 0
        for slot in snapshot.pods.indices where snapshot.pods[slot] != nil {
            if slot < snapshot.grownAt.count, let cycle = snapshot.grownAt[slot], cycle <= snapshot.shownCycle {
                count += 1
            }
        }
        return count
    }

    /// The number of colonies of `snapshot` whose humidity at the shown cycle lies in their band.
    static func inBand(_ snapshot: MushroomWeatherSceneSnapshot) -> Int {
        var count: Int = 0
        for colony in snapshot.colonies {
            let humidity: Int = snapshot.humidity(colony.cell)
            if colony.low <= humidity && humidity <= colony.high { count += 1 }
        }
        return count
    }
}

/// The code-only golden frames of Mushroom Weather against the pinned file (see the file header).
@Suite struct MushroomWeatherRegressionGoldenTests {
    /// The 16 frames, their order, unique names, levels, tiers, time, actions and cycles; each level frame applies all
    /// of its stored witness's arrangement actions (never the run) at the cycle half the cycles run; the hero frame
    /// applies the hero level's actions and shows the hero cycle.
    @Test func theGoldenSetIsFixed() throws {
        typealias Core = MushroomWeatherExperienceCore
        let frames: [MushroomWeatherGolden.Frame] = MushroomWeatherGolden.frames
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
        #expect(MushroomWeatherGolden.levels == levels)
        #expect(MushroomWeatherGolden.width == 1_152)
        #expect(MushroomWeatherGolden.height == 768)
        #expect(MushroomWeatherGolden.schema == 1)
        #expect(MushroomWeatherGolden.quantum == 8)
        #expect(MushroomWeatherGolden.time == 0)
        #expect(MushroomWeatherGolden.writeSwitch == "MUSHROOM_WEATHER_WRITE_GOLDEN")
        #expect(MushroomWeatherGolden.colourNames == GoldenSupport.colourNames)
        try #require(frames.count == 16)
        var index: Int = 0
        for level in levels {
            let changes: [MushroomWeatherAction] = try GoldenSupport.witnessChanges(level)
            #expect(!changes.isEmpty, "level \(level) witness has no arrangement action")
            #expect(Core.certifiedActions(level) == changes, "level \(level) certified plan is not the witness's")
            let opening: MushroomWeatherExperienceCore = try Core.opening(number: level)
            var play: MushroomWeatherPlay = opening.play
            for action in changes { try play.apply(action, expecting: play.fingerprint) }
            let half: Int = play.report.cycles / 2
            for tier in 0..<3 {
                let frame: MushroomWeatherGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.cycle == half, "\(frame.name) cycle \(frame.cycle), half \(half)")
                #expect(frame.name == MushroomWeatherGolden.name(level: level, tier: tier))
                #expect(frame.actions == changes, "\(frame.name) actions")
                #expect(!frame.actions.contains(.run), "\(frame.name) applies the run")
                index += 1
            }
        }
        let hero: MushroomWeatherGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        let heroChanges: [MushroomWeatherAction] = try GoldenSupport.witnessChanges(heroLevel)
        #expect(hero.actions == heroChanges)
        #expect(!hero.actions.contains(.run), "hero applies the run")
        let heroCycle: Int = try #require(Core.heroCycle(heroLevel))
        #expect(hero.cycle == heroCycle, "hero cycle \(hero.cycle)")
        // The hero scenario is the certified actions, then one shown cycle.
        #expect(Core.heroEntries.count == hero.actions.count + 1)
    }

    /// The shown cycle is 0 and no action is applied for a level that cannot be generated.
    @Test func aLevelOutsideTheCatalogShowsCycleZero() {
        let outside: [Int] = [0, 101]
        for number in outside {
            let cycle: Int = MushroomWeatherGolden.shownCycle(number)
            #expect(cycle == 0, "level \(number) cycle \(cycle)")
            #expect(MushroomWeatherGolden.openActions(number).isEmpty, "level \(number) applies an action")
        }
    }

    /// Every frame is still open: stage `playing`, the predicted run wins, no preview, the actions bars partly spent,
    /// the shown cycle half the cycles run (the hero cycle, the last, for the hero) and the run then wins it.
    @Test func everyFrameIsOpenAndTheRunWinsIt() throws {
        for frame in MushroomWeatherGolden.frames {
            let level: MushroomWeatherLevel = try MushroomWeatherExperienceCore.level(number: frame.level)
            var play: MushroomWeatherPlay = try MushroomWeatherExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: MushroomWeatherSceneSnapshot = try MushroomWeatherGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) predicts a failure")
            #expect(snapshot.preview == nil, "\(frame.name) previews a drag")
            #expect(snapshot.time == 0)
            #expect(snapshot.levelNumber == frame.level)
            #expect(snapshot.shownCycle == frame.cycle, "\(frame.name) shown cycle \(snapshot.shownCycle)")
            if frame.name == "hero" {
                #expect(snapshot.shownCycle == snapshot.cyclesRun, "hero shows cycle \(snapshot.shownCycle)")
            } else {
                #expect(snapshot.shownCycle == snapshot.cyclesRun / 2, "\(frame.name) half cycle")
            }
            #expect(snapshot.actionsLeft < snapshot.budget, "\(frame.name) no spent actions bar")
            var finished: MushroomWeatherPlay = play
            try finished.apply(.run, expecting: finished.fingerprint)
            #expect(finished.stage == .won, "\(frame.name) the run does not win (\(finished.stage))")
        }
    }

    /// Every frame's description has the frame's identity, size and cycle, the floor centre, the moon centre, the
    /// first gauge track, one position per colony cap, every cap projecting, a first actions bar exactly when the
    /// budget is positive, counts and moonlight that match the snapshot, and the Core's palette.
    @Test func everyFrameDescribesItsSnapshot() throws {
        typealias G = MushroomWeatherSceneGeometry
        for frame in MushroomWeatherGolden.frames {
            let snapshot: MushroomWeatherSceneSnapshot = try MushroomWeatherGolden.snapshot(frame)
            let description: MushroomWeatherGolden.Description = try MushroomWeatherGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            #expect(description.cycle == snapshot.shownCycle)
            #expect(description.floor != nil, "\(frame.name) floor centre behind the eye")
            #expect(description.moon != nil, "\(frame.name) moon centre behind the eye")
            #expect(description.firstGaugeTrack != nil, "\(frame.name) first gauge track behind the eye")
            #expect(description.caps.count == snapshot.colonies.count, "\(frame.name) cap points")
            for point in description.caps { #expect(point != nil, "\(frame.name) cap behind the eye") }
            #expect((description.firstActionsBar == nil) == (snapshot.budget <= 0), "\(frame.name) first actions bar")
            #expect(description.moonlight == snapshot.moonlight, "\(frame.name) moonlight")
            let counts: MushroomWeatherGolden.Counts = description.counts
            let cells: Int = snapshot.rows * snapshot.columns
            #expect(counts.floor + counts.blocked == cells, "\(frame.name) floor and blocked cells")
            #expect(counts.blocked == snapshot.blocked.count, "\(frame.name) blocked")
            #expect(counts.mist == counts.floor, "\(frame.name) mist squares")
            #expect(counts.sites == snapshot.sites.count, "\(frame.name) sites")
            #expect(counts.pods == GoldenSupport.placedPods(snapshot), "\(frame.name) pods")
            #expect(counts.grown == GoldenSupport.grownPods(snapshot), "\(frame.name) grown pods")
            #expect(counts.grown <= counts.pods, "\(frame.name) grown beyond pods")
            #expect(counts.vents == snapshot.vents.count, "\(frame.name) vents")
            var open: Int = 0
            for state in snapshot.ventsOpen where state { open += 1 }
            #expect(counts.open == open, "\(frame.name) open vents")
            #expect(counts.colonies == snapshot.colonies.count, "\(frame.name) colonies")
            #expect(counts.inBand == GoldenSupport.inBand(snapshot), "\(frame.name) in band")
            #expect(counts.litActions == G.litActions(snapshot), "\(frame.name) lit actions")
            #expect(counts.litActions == snapshot.actionsLeft, "\(frame.name) lit actions against actions left")
            #expect(counts.actions == max(snapshot.budget, 0), "\(frame.name) actions total")
            #expect(counts.litActions < counts.actions, "\(frame.name) no spent actions bar")
            #expect(description.colours.count == 21)
            for name in MushroomWeatherGolden.colourNames {
                let expected: [Int] = MushroomWeatherGolden.colour(MushroomWeatherGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
        }
        // The hero frame shows the last cycle of a winning run: every colony is in band there.
        let hero: MushroomWeatherGolden.Description = try MushroomWeatherGolden.describe(try GoldenSupport.frame("hero"))
        #expect(hero.counts.inBand == hero.counts.colonies, "hero in band \(hero.counts.inBand)")
    }

    /// The tiers of one level share every position, count, cycle, moonlight and colour; only their identity differs.
    @Test func tiersShareEveryPositionAndCount() throws {
        for level in MushroomWeatherGolden.levels {
            var described: [MushroomWeatherGolden.Description] = []
            for tier in 0..<3 {
                let name: String = MushroomWeatherGolden.name(level: level, tier: tier)
                described.append(try MushroomWeatherGolden.describe(try GoldenSupport.frame(name)))
            }
            try #require(described.count == 3)
            for tier in 1..<3 {
                let a: MushroomWeatherGolden.Description = described[0]
                let b: MushroomWeatherGolden.Description = described[tier]
                #expect(a.floor == b.floor && a.caps == b.caps && a.moon == b.moon
                        && a.firstGaugeTrack == b.firstGaugeTrack && a.firstActionsBar == b.firstActionsBar,
                        "level \(level) tier \(tier) positions")
                #expect(a.counts == b.counts, "level \(level) tier \(tier) counts")
                #expect(a.cycle == b.cycle && a.moonlight == b.moonlight && a.colours == b.colours,
                        "level \(level) tier \(tier) cycle, moonlight or colours")
                #expect(b.tier == tier && b.name != a.name, "level \(level) tier \(tier) identity")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run.
    @Test func descriptionsAreDeterministic() throws {
        for frame in MushroomWeatherGolden.frames {
            let first: Data = try MushroomWeatherGolden.description(frame)
            let second: Data = try MushroomWeatherGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try MushroomWeatherGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try MushroomWeatherGolden.manifest()
        let again: Data = try MushroomWeatherGolden.manifest()
        #expect(manifest == again)
    }

    /// Every frame matches the pinned file, which has schema 1, exactly the 16 frame names and equals `manifest()` for
    /// the current code; the file is written only with MUSHROOM_WEATHER_WRITE_GOLDEN=1 (the regeneration hook).
    @Test func everyFrameMatchesThePinnedFile() throws {
        let file: URL = GoldenSupport.file
        let before: Data? = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        if GoldenSupport.writing {
            let written: Bool = try MushroomWeatherGolden.writeIfRequested(to: file)
            #expect(written)
            let manifest: Data = try MushroomWeatherGolden.manifest()
            let onDisk: Data = try Data(contentsOf: file)
            #expect(onDisk == manifest, "the written file is not MushroomWeatherGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            Issue.record("""
                \(file.path) is missing; review the visuals and run with MUSHROOM_WEATHER_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter MushroomWeatherRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: file)
        let decoded: MushroomWeatherGolden.Manifest = try JSONDecoder().decode(MushroomWeatherGolden.Manifest.self,
                                                                               from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == GoldenSupport.expectedNames.sorted())
        let nameProblem: String? = try GoldenSupport.nameProblem(pinned)
        #expect(nameProblem == nil, "\(nameProblem ?? "")")
        let current: MushroomWeatherGolden.Manifest = try JSONDecoder().decode(
            MushroomWeatherGolden.Manifest.self, from: try MushroomWeatherGolden.manifest())
        #expect(current == decoded, "golden-frames.json is not manifest() for the current code")
        for frame in MushroomWeatherGolden.frames {
            let result: String? = try MushroomWeatherGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
            let entry: MushroomWeatherGolden.Entry = try #require(decoded.frames[frame.name])
            let recomputed: Data = try MushroomWeatherGolden.description(frame)
            let pinnedDescription: Data = try MushroomWeatherGolden.encoder.encode(entry.description)
            #expect(recomputed == pinnedDescription, "\(frame.name) description")
            let digest: String = try MushroomWeatherGolden.digest(frame)
            #expect(entry.digest == digest, "\(frame.name) digest")
        }
        if !GoldenSupport.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: file)
            #expect(after == before, "golden-frames.json changed without MUSHROOM_WEATHER_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mushroom-weather-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["MUSHROOM_WEATHER_WRITE_GOLDEN": "0"], ["MUSHROOM_WEATHER_WRITE_GOLDEN": ""],
            ["MUSHROOM_WEATHER_WRITE_GOLDEN": "true"], ["MICROSCOPIC_AURORA_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try MushroomWeatherGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let existing: Data = Data("an existing file".utf8)
        try existing.write(to: target)
        let refused: Bool = try MushroomWeatherGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        let untouched: Data = try Data(contentsOf: target)
        #expect(untouched == existing, "an existing file was touched without the switch")
        let written: Bool = try MushroomWeatherGolden.writeIfRequested(
            to: target, environment: ["MUSHROOM_WEATHER_WRITE_GOLDEN": "1"])
        #expect(written)
        let rewritten: Data = try Data(contentsOf: target)
        let manifest: Data = try MushroomWeatherGolden.manifest()
        #expect(rewritten == manifest)
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let root: [String: Any] = try GoldenSupport.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in MushroomWeatherGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            let recomputed: String = try GoldenSupport.digest(of: description)
            #expect(pinnedDigest == recomputed, "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    /// An unreadable file, schema ≠ 1, a missing, renamed, unknown or extra frame and an identity, size or cycle change
    /// are named.
    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let first: MushroomWeatherGolden.Frame = try GoldenSupport.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try MushroomWeatherGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try MushroomWeatherGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try GoldenSupport.tree(data)
            root["schema"] = value
            let schema: String? = try MushroomWeatherGolden.compare(first, pinned: try GoldenSupport.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try GoldenSupport.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try GoldenSupport.bytes(incomplete)
        let missing: String? = try MushroomWeatherGolden.compare(try GoldenSupport.frame("level-041-tier-1"),
                                                                 pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try MushroomWeatherGolden.compare(first, pinned: shortened)
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
        let renamed: String? = try MushroomWeatherGolden.compare(try GoldenSupport.frame("level-061-tier-2"),
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
        let identityResult: String? = try MushroomWeatherGolden.compare(
            try GoldenSupport.frame("level-081-tier-0"), pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try MushroomWeatherGolden.compare(
                try GoldenSupport.frame("level-021-tier-0"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let sizeKeys: [String] = ["width", "height", "quantum"]
        for key in sizeKeys {
            let size: String? = try MushroomWeatherGolden.compare(
                try GoldenSupport.frame("level-021-tier-2"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-2", key: key, by: 1))
            #expect(size == "level-021-tier-2: size differs", "\(key): \(size ?? "nil")")
        }

        // A changed shown cycle is named.
        let cycle: String? = try MushroomWeatherGolden.compare(
            try GoldenSupport.frame("hero"), pinned: try GoldenSupport.shifted(data, frame: "hero", key: "cycle", by: 1))
        #expect(cycle?.hasPrefix("hero: cycle ") == true, "\(cycle ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: MushroomWeatherGolden.Frame = MushroomWeatherGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [], cycle: 0)
        let unknownResult: String? = try MushroomWeatherGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// The floor centre, the moon centre, the first gauge track, the first actions bar or a cap moved by two quanta
    /// fails naming the frame; one quantum passes; a removed cap is named as a different number of points.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let singles: [String] = ["floor", "moon", "firstGaugeTrack", "firstActionsBar"]
        let singleWords: [String] = ["floor centre", "moon centre", "first gauge track", "first actions bar"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try GoldenSupport.firstPlacedSingle(data, key: key)
            let frame: MushroomWeatherGolden.Frame = try GoldenSupport.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try MushroomWeatherGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try MushroomWeatherGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try MushroomWeatherGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }

        let placed: (frame: String, index: Int) = try #require(try GoldenSupport.firstPlacedCap(data),
                                                               "no frame has a cap position")
        let name: String = placed.frame
        let index: Int = placed.index
        let frame: MushroomWeatherGolden.Frame = try GoldenSupport.frame(name)

        let far: String? = try MushroomWeatherGolden.compare(
            frame, pinned: try GoldenSupport.movedCap(data, frame: name, index: index, dx: 2))
        #expect(far?.hasPrefix("\(name): cap \(index) at ") == true, "caps: \(far ?? "nil")")

        let farY: String? = try MushroomWeatherGolden.compare(
            frame, pinned: try GoldenSupport.movedCap(data, frame: name, index: index, dy: -2))
        #expect(farY?.hasPrefix("\(name): cap \(index) at ") == true, "caps: \(farY ?? "nil")")

        let near: String? = try MushroomWeatherGolden.compare(
            frame, pinned: try GoldenSupport.movedCap(data, frame: name, index: index, dx: 1, dy: 1))
        #expect(near == nil, "caps: \(near ?? "")")

        let fewer: Data = try GoldenSupport.edited(data, frame: name) { description in
            var points: [Any] = try #require(description["caps"] as? [Any])
            points.removeLast()
            description["caps"] = points
        }
        let fewerResult: String? = try MushroomWeatherGolden.compare(frame, pinned: fewer)
        #expect(fewerResult?.hasPrefix("\(name): ") == true, "caps: \(fewerResult ?? "nil")")
        #expect(fewerResult?.contains("cap points, pinned") == true, "caps: \(fewerResult ?? "nil")")
    }

    /// A changed colour, count or moonlight fails naming the frame.
    @Test func colourCountAndMoonlightChangesAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: MushroomWeatherGolden.Frame = try GoldenSupport.frame(name)

        for colourName in MushroomWeatherGolden.colourNames {
            let palette: Data = try GoldenSupport.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [Int] = try #require(colours[colourName] as? [Int])
                try #require(colour.count == 3)
                colour[1] = colour[1] == 255 ? 254 : colour[1] + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try MushroomWeatherGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = [
            "floor", "blocked", "mist", "sites", "pods", "grown", "vents", "open", "colonies", "inBand", "litActions",
            "actions",
        ]
        for key in countKeys {
            let counts: String? = try MushroomWeatherGolden.compare(
                frame, pinned: try GoldenSupport.shiftedCount(data, frame: name, key: key, by: 1))
            #expect(counts?.hasPrefix("\(name): counts differ") == true, "\(key): \(counts ?? "nil")")
        }

        let moonlight: String? = try MushroomWeatherGolden.compare(
            frame, pinned: try GoldenSupport.shifted(data, frame: name, key: "moonlight", by: 1))
        #expect(moonlight?.hasPrefix("\(name): moonlight ") == true, "\(moonlight ?? "nil")")
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let edited: Data = try GoldenSupport.edited(data, frame: "hero", redigest: false) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            counts["actions"] = 99
            description["counts"] = counts
        }
        let message: String? = try MushroomWeatherGolden.compare(try GoldenSupport.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try GoldenSupport.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            if let point = description["floor"] as? [Int], point.count == 2 {
                description["floor"] = [point[0] + 1, point[1]]
            } else {
                description["floor"] = [0, 0]
            }
        }
        let movedMessage: String? = try MushroomWeatherGolden.compare(
            try GoldenSupport.frame("level-021-tier-1"), pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
