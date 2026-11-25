// CelestialEclipseLabRegressionGoldenTests — feature 468 (R02-G17-08) T-R02G1708-004 (FR-R02G1708-003, 004;
// SC-R02G1708-003; clarification Q3). The code-only visual baseline of Celestial Eclipse Lab: the fixed golden set of
// 16 frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0, each after all certified phase changes of its level
// but not the run, with the default chosen body at the first tick of the predicted timeline with an eclipse under way,
// then the hero frame: the level the hero scenario opens, seed `manifestSeed`, after the same phase changes with the
// last moved body chosen and the hero tick shown, tier 0) in its fixed order with unique names; every frame is still
// open, its actions gauge is partly spent whenever a change was applied and the run then wins it; every frame's counts
// match the snapshot and its palette (21 colours) is the Core's; deterministic descriptions and digests; every frame's
// recomputed description against the pinned file CelestialEclipseLab/golden-frames.json, which holds exactly the 16
// frame names under schema 1 and equals `manifest()` for the current code; every pinned digest against the digest of
// its pinned description; and the failures the comparison must name, built from the pinned manifest in memory (the
// pinned file is never written by them): a position moved by two 1/8-pixel quanta fails naming the frame while one
// quantum passes, a changed palette colour, a changed count, a changed identity, size, body or tick, a missing frame,
// a renamed or unknown frame, an unknown extra entry in the file (checked by name equality, as `compare` looks up one
// frame at a time), a schema other than 1, an unreadable file and a hand-edited description that kept its old digest.
// A position may be null in the schema (a point that does not project or lies outside the frame); the helpers that
// pick a position to move skip nulls. `writeIfRequested` is exercised on a temporary file only: it writes nothing
// without the switch and exactly the manifest with it.
//
// The pinned file is written only when CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed
// visual change:
//     CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter CelestialEclipseLabRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule), and no `try` inside
// `#expect`. Modelled on StarlitCartoucheRegressionGoldenTests (feature 458).
import Foundation
import Testing
import VisualCoreMath
@testable import CelestialEclipseLabCore

/// File-private helpers of the golden tests, kept in one namespace so no name collides with other files of the target.
private enum GoldenSupport {
    /// The pinned golden file, found from this file (…/CelestialEclipseLab/CoreTests/ → ../golden-frames.json).
    static let file: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("golden-frames.json", isDirectory: false)

    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[CelestialEclipseLabGolden.writeSwitch] == "1"
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

    /// The 21 described palette colours in the order the comparison checks them.
    static let colourNames: [String] = [
        "ink", "inkTop", "speck", "disc", "discShade", "orbit", "fixedFrame", "chosen", "corona", "coronaGlow",
        "crescentShadow", "ember", "window", "matched", "unwanted", "faintEvent", "playhead", "actionsLit",
        "actionsUnlit", "broken", "glow",
    ]

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: file.path) { return try Data(contentsOf: file) }
        return try CelestialEclipseLabGolden.manifest()
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
        let decoded: CelestialEclipseLabGolden.Description = try JSONDecoder().decode(
            CelestialEclipseLabGolden.Description.self, from: data)
        return try CelestialEclipseLabGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in CelestialEclipseLabGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with position `index` (0-based) of the list `key` (`bodies`, `lenses`, `halos`) of
    /// `frame`'s description moved by `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// The manifest `data` with the single position `key` (`playhead`, `firstActionsBar`) of `frame` moved by `dx`,
    /// `dy` quanta.
    static func movedSingle(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// A pinned position in the list `key`: the first golden frame (in the fixed order) whose pinned description has
    /// one on screen (not null), and the 0-based index of that position; nil when no frame has one.
    static func firstPlaced(_ data: Data, key: String) throws -> (frame: String, index: Int)? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in CelestialEclipseLabGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description[key] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        return nil
    }

    /// The first golden frame (in the fixed order) whose pinned description has the single position `key` on screen
    /// (not null).
    static func firstPlacedSingle(_ data: Data, key: String) throws -> String {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in CelestialEclipseLabGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> CelestialEclipseLabGolden.Frame {
        for frame in CelestialEclipseLabGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The number of eclipses in `snapshot` that draw a halo.
    static func haloCount(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Int {
        var count: Int = 0
        for eclipse in snapshot.eclipses where CelestialEclipseLabSceneGeometry.hasHalo(eclipse) { count += 1 }
        return count
    }
}

/// The code-only golden frames of Celestial Eclipse Lab against the pinned file (see the file header).
@Suite struct CelestialEclipseLabRegressionGoldenTests {
    /// The 16 frames, their order, unique names, levels, tiers, time, choices and ticks; each level frame applies all
    /// certified phase changes of its level with the default choice at its first eclipse tick; the hero frame applies
    /// the hero level's changes, chooses the last moved body and shows the hero tick.
    @Test func theGoldenSetIsFixed() throws {
        typealias Core = CelestialEclipseLabExperienceCore
        let frames: [CelestialEclipseLabGolden.Frame] = CelestialEclipseLabGolden.frames
        #expect(frames.count == 16)
        var actualNames: [String] = []
        var names: Set<String> = []
        for frame in frames {
            actualNames.append(frame.name)
            names.insert(frame.name)
        }
        #expect(names.count == 16)
        #expect(names.contains("hero"))
        #expect(actualNames == GoldenSupport.expectedNames)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(CelestialEclipseLabGolden.levels == levels)
        #expect(CelestialEclipseLabGolden.width == 1_152)
        #expect(CelestialEclipseLabGolden.height == 768)
        #expect(CelestialEclipseLabGolden.schema == 1)
        #expect(CelestialEclipseLabGolden.quantum == 8)
        #expect(CelestialEclipseLabGolden.time == 0)
        #expect(CelestialEclipseLabGolden.writeSwitch == "CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN")
        #expect(CelestialEclipseLabGolden.colourNames == GoldenSupport.colourNames)
        #expect(CelestialEclipseLabGolden.colourNames.count == 21)
        try #require(frames.count == 16)
        var index: Int = 0
        for level in levels {
            let certified: [CelestialEclipseLabAction] = Core.certifiedActions(level)
            #expect(!certified.isEmpty, "level \(level) has no certified plan")
            let tick: Int = CelestialEclipseLabGolden.firstEclipseTick(level, after: certified)
            for tier in 0..<3 {
                let frame: CelestialEclipseLabGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.chosenBody == nil, "\(frame.name) chosen body \(String(describing: frame.chosenBody))")
                #expect(frame.tick == tick, "\(frame.name) tick \(frame.tick)")
                #expect(frame.name == CelestialEclipseLabGolden.name(level: level, tier: tier))
                #expect(frame.actions == certified, "\(frame.name) actions")
                #expect(!frame.actions.contains(.run), "\(frame.name) applies the run")
                index += 1
            }
        }
        let hero: CelestialEclipseLabGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        let heroCertified: [CelestialEclipseLabAction] = Core.certifiedActions(heroLevel)
        let last: CelestialEclipseLabAction = try #require(heroCertified.last)
        #expect(hero.actions == heroCertified)
        #expect(hero.chosenBody == Core.phaseBody(of: last), "hero body \(String(describing: hero.chosenBody))")
        let heroTick: Int = try #require(Core.heroTick(heroLevel))
        #expect(hero.tick == heroTick, "hero tick \(hero.tick)")
        // The hero scenario is the phase changes, then one choice of body and one shown tick.
        #expect(Core.heroEntries.count == hero.actions.count + 2)
    }

    /// The first eclipse tick is 0 for a level that cannot be generated, and otherwise a tick of the horizon at which
    /// the predicted timeline has an eclipse under way (or 0 when it has none).
    @Test func theFirstEclipseTickIsAnEclipseOrZero() throws {
        let outside: [Int] = [0, 101]
        for number in outside {
            let tick: Int = CelestialEclipseLabGolden.firstEclipseTick(number, after: [])
            #expect(tick == 0, "level \(number) tick \(tick)")
            #expect(CelestialEclipseLabGolden.openChanges(number).isEmpty, "level \(number) applies a change")
        }
        for level in CelestialEclipseLabGolden.levels {
            let certified: [CelestialEclipseLabAction] = CelestialEclipseLabExperienceCore.certifiedActions(level)
            #expect(CelestialEclipseLabGolden.openChanges(level) == certified, "level \(level) open changes")
            let tick: Int = CelestialEclipseLabGolden.firstEclipseTick(level, after: certified)
            let generated: CelestialEclipseLabLevel = try CelestialEclipseLabExperienceCore.level(number: level)
            var play: CelestialEclipseLabPlay = try CelestialEclipseLabExperienceCore.freshPlay(of: generated)
            for change in certified { try play.apply(change, expecting: play.fingerprint) }
            #expect(tick >= 0 && tick < play.level.horizon, "level \(level) tick \(tick)")
            let eclipses: [CelestialEclipseLabEclipse] = CelestialEclipseLabSceneSnapshot.eclipses(
                play.level, phases: play.phases, tick: tick)
            var earlier: Int = 0
            for before in 0..<tick {
                let found: [CelestialEclipseLabEclipse] = CelestialEclipseLabSceneSnapshot.eclipses(
                    play.level, phases: play.phases, tick: before)
                earlier += found.count
            }
            #expect(earlier == 0, "level \(level) has an eclipse before tick \(tick)")
            if tick > 0 { #expect(!eclipses.isEmpty, "level \(level) shows no eclipse at tick \(tick)") }
        }
    }

    /// Every frame is still open: stage `playing`, no failure, not won, the actions gauge partly spent whenever a
    /// change was applied, and the run then wins it.
    @Test func everyFrameIsOpenAndTheRunWinsIt() throws {
        for frame in CelestialEclipseLabGolden.frames {
            let level: CelestialEclipseLabLevel = try CelestialEclipseLabExperienceCore.level(number: frame.level)
            var play: CelestialEclipseLabPlay = try CelestialEclipseLabExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: CelestialEclipseLabSceneSnapshot = try CelestialEclipseLabGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            #expect(!snapshot.isWon, "\(frame.name) is won")
            #expect(snapshot.levelNumber == frame.level)
            #expect(snapshot.shownTick == frame.tick, "\(frame.name) shown tick \(snapshot.shownTick)")
            if let body = frame.chosenBody {
                #expect(snapshot.chosenBody == body, "\(frame.name) chosen body \(snapshot.chosenBody)")
            } else {
                let expected: Int = CelestialEclipseLabSceneSnapshot.defaultChoice(play.level)
                #expect(snapshot.chosenBody == expected, "\(frame.name) default body \(snapshot.chosenBody)")
            }
            if !frame.actions.isEmpty {
                #expect(snapshot.actionsLeft < snapshot.budget, "\(frame.name) no spent actions bar")
            }
            var finished: CelestialEclipseLabPlay = play
            try finished.apply(.run, expecting: finished.fingerprint)
            #expect(finished.stage == .won, "\(frame.name) the run does not win (\(finished.stage))")
        }
    }

    /// Every frame's description has the frame's identity and size, one position per body, per eclipse lens and per
    /// halo, a first actions bar exactly when the budget is positive, counts that match the snapshot and the Core's
    /// palette.
    @Test func everyFrameDescribesItsSnapshot() throws {
        typealias G = CelestialEclipseLabSceneGeometry
        for frame in CelestialEclipseLabGolden.frames {
            let snapshot: CelestialEclipseLabSceneSnapshot = try CelestialEclipseLabGolden.snapshot(frame)
            let description: CelestialEclipseLabGolden.Description = try CelestialEclipseLabGolden.describe(frame)
            let halos: Int = GoldenSupport.haloCount(snapshot)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            #expect(description.chosenBody == snapshot.chosenBody)
            #expect(description.tick == snapshot.shownTick)
            #expect(description.bodies.count == snapshot.positions.count, "\(frame.name) body points")
            #expect(description.lenses.count == snapshot.eclipses.count, "\(frame.name) lens points")
            #expect(description.halos.count == halos, "\(frame.name) halo points")
            #expect((description.firstActionsBar == nil) == (snapshot.budget <= 0), "\(frame.name) first actions bar")
            #expect(description.counts.bodies == snapshot.bodies.count, "\(frame.name) bodies")
            #expect(description.counts.rings == snapshot.bodies.count, "\(frame.name) rings")
            #expect(description.counts.lenses == snapshot.eclipses.count, "\(frame.name) lenses")
            #expect(description.counts.halos == halos, "\(frame.name) halos")
            #expect(description.counts.targets == snapshot.target.count, "\(frame.name) targets")
            #expect(description.counts.matched == snapshot.matched, "\(frame.name) matched")
            #expect(description.counts.matched <= description.counts.targets, "\(frame.name) matched beyond targets")
            #expect(description.counts.litActions == G.litActions(snapshot), "\(frame.name) lit actions")
            #expect(description.counts.actions == max(snapshot.budget, 0), "\(frame.name) actions total")
            #expect(description.counts.litActions <= description.counts.actions, "\(frame.name) lit beyond total")
            #expect(description.colours.count == 21)
            for name in CelestialEclipseLabGolden.colourNames {
                let expected: CelestialEclipseLabGolden.Colour = CelestialEclipseLabGolden.colour(
                    CelestialEclipseLabGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run.
    @Test func descriptionsAreDeterministic() throws {
        for frame in CelestialEclipseLabGolden.frames {
            let first: Data = try CelestialEclipseLabGolden.description(frame)
            let second: Data = try CelestialEclipseLabGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try CelestialEclipseLabGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try CelestialEclipseLabGolden.manifest()
        let again: Data = try CelestialEclipseLabGolden.manifest()
        #expect(manifest == again)
    }

    /// Every frame matches the pinned file, which has schema 1, exactly the 16 frame names and equals `manifest()` for
    /// the current code; the file is written only with CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1 (the regeneration hook).
    @Test func everyFrameMatchesThePinnedFile() throws {
        let file: URL = GoldenSupport.file
        let before: Data? = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        if GoldenSupport.writing {
            let written: Bool = try CelestialEclipseLabGolden.writeIfRequested(to: file)
            #expect(written)
            let manifest: Data = try CelestialEclipseLabGolden.manifest()
            let onDisk: Data = try Data(contentsOf: file)
            #expect(onDisk == manifest, "the written file is not CelestialEclipseLabGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            Issue.record("""
                \(file.path) is missing; review the visuals and run with CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter CelestialEclipseLabRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: file)
        let decoded: CelestialEclipseLabGolden.Manifest = try JSONDecoder().decode(
            CelestialEclipseLabGolden.Manifest.self, from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == GoldenSupport.expectedNames.sorted())
        let nameProblem: String? = try GoldenSupport.nameProblem(pinned)
        #expect(nameProblem == nil, "\(nameProblem ?? "")")
        let current: CelestialEclipseLabGolden.Manifest = try JSONDecoder().decode(
            CelestialEclipseLabGolden.Manifest.self, from: try CelestialEclipseLabGolden.manifest())
        #expect(current == decoded, "golden-frames.json is not manifest() for the current code")
        for frame in CelestialEclipseLabGolden.frames {
            let result: String? = try CelestialEclipseLabGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
            let entry: CelestialEclipseLabGolden.Entry = try #require(decoded.frames[frame.name])
            let recomputed: Data = try CelestialEclipseLabGolden.description(frame)
            let pinnedDescription: Data = try CelestialEclipseLabGolden.encoder.encode(entry.description)
            #expect(recomputed == pinnedDescription, "\(frame.name) description")
            let digest: String = try CelestialEclipseLabGolden.digest(frame)
            #expect(entry.digest == digest, "\(frame.name) digest")
        }
        if !GoldenSupport.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: file)
            #expect(after == before, "golden-frames.json changed without CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("celestial-eclipse-lab-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN": "0"], ["CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN": ""],
            ["CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN": "true"], ["STARLIT_CARTOUCHE_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try CelestialEclipseLabGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let placeholder: Data = Data("placeholder".utf8)
        try placeholder.write(to: target)
        let refused: Bool = try CelestialEclipseLabGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        let untouched: Data = try Data(contentsOf: target)
        #expect(untouched == placeholder, "an existing file was touched without the switch")
        let written: Bool = try CelestialEclipseLabGolden.writeIfRequested(
            to: target, environment: ["CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN": "1"])
        #expect(written)
        let rewritten: Data = try Data(contentsOf: target)
        let manifest: Data = try CelestialEclipseLabGolden.manifest()
        #expect(rewritten == manifest)
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let root: [String: Any] = try GoldenSupport.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in CelestialEclipseLabGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            let recomputed: String = try GoldenSupport.digest(of: description)
            #expect(pinnedDigest == recomputed, "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    /// An unreadable file, schema ≠ 1, a missing, renamed, unknown or extra frame and an identity, size, body or tick
    /// change are named.
    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let first: CelestialEclipseLabGolden.Frame = try GoldenSupport.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try CelestialEclipseLabGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try CelestialEclipseLabGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try GoldenSupport.tree(data)
            root["schema"] = value
            let schema: String? = try CelestialEclipseLabGolden.compare(first, pinned: try GoldenSupport.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try GoldenSupport.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try GoldenSupport.bytes(incomplete)
        let missing: String? = try CelestialEclipseLabGolden.compare(try GoldenSupport.frame("level-041-tier-1"),
                                                                     pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try CelestialEclipseLabGolden.compare(first, pinned: shortened)
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
        let renamed: String? = try CelestialEclipseLabGolden.compare(try GoldenSupport.frame("level-061-tier-2"),
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
        let identityResult: String? = try CelestialEclipseLabGolden.compare(
            try GoldenSupport.frame("level-081-tier-0"), pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try CelestialEclipseLabGolden.compare(
                try GoldenSupport.frame("level-021-tier-0"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let size: String? = try CelestialEclipseLabGolden.compare(
            try GoldenSupport.frame("level-021-tier-2"),
            pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-2", key: "width", by: 1))
        #expect(size == "level-021-tier-2: size differs", "\(size ?? "nil")")

        // A changed chosen body or shown tick is named.
        let choiceKeys: [String] = ["chosenBody", "tick"]
        for key in choiceKeys {
            let choice: String? = try CelestialEclipseLabGolden.compare(
                try GoldenSupport.frame("hero"),
                pinned: try GoldenSupport.shifted(data, frame: "hero", key: key, by: 1))
            #expect(choice?.hasPrefix("hero: body ") == true, "\(key): \(choice ?? "nil")")
        }

        // An unknown frame (not in the golden set) is named.
        let unknown: CelestialEclipseLabGolden.Frame = CelestialEclipseLabGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [], chosenBody: nil, tick: 0)
        let unknownResult: String? = try CelestialEclipseLabGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// A body centre, shadow lens, halo, the playhead or the first actions bar moved by two quanta fails naming the
    /// frame; one quantum passes; a removed position is named as a different number of points. Bodies and lenses must
    /// be placed in some frame; halos are checked when a frame places one.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let keys: [String] = ["bodies", "lenses", "halos"]
        let words: [String] = ["body centre", "shadow lens", "halo"]
        let required: [Bool] = [true, true, false]
        for (keyIndex, key) in keys.enumerated() {
            guard let placed = try GoldenSupport.firstPlaced(data, key: key) else {
                if required[keyIndex] { Issue.record("no golden frame has a placed \(key) position") }
                continue
            }
            let name: String = placed.frame
            let index: Int = placed.index
            let frame: CelestialEclipseLabGolden.Frame = try GoldenSupport.frame(name)
            let word: String = words[keyIndex]

            let far: String? = try CelestialEclipseLabGolden.compare(
                frame, pinned: try GoldenSupport.moved(data, frame: name, key: key, index: index, dx: 2))
            #expect(far?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(far ?? "nil")")

            let farY: String? = try CelestialEclipseLabGolden.compare(
                frame, pinned: try GoldenSupport.moved(data, frame: name, key: key, index: index, dy: -2))
            #expect(farY?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(farY ?? "nil")")

            let near: String? = try CelestialEclipseLabGolden.compare(
                frame, pinned: try GoldenSupport.moved(data, frame: name, key: key, index: index, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")

            let fewer: Data = try GoldenSupport.edited(data, frame: name) { description in
                var points: [Any] = try #require(description[key] as? [Any])
                points.removeLast()
                description[key] = points
            }
            let fewerResult: String? = try CelestialEclipseLabGolden.compare(frame, pinned: fewer)
            #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(key): \(fewerResult ?? "nil")")
            #expect(fewerResult?.contains("\(word) points, pinned") == true, "\(key): \(fewerResult ?? "nil")")
        }

        let singles: [String] = ["playhead", "firstActionsBar"]
        let singleWords: [String] = ["playhead", "first actions bar"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try GoldenSupport.firstPlacedSingle(data, key: key)
            let frame: CelestialEclipseLabGolden.Frame = try GoldenSupport.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try CelestialEclipseLabGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try CelestialEclipseLabGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try CelestialEclipseLabGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: 1, dy: 1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }
    }

    /// A changed colour or count fails naming the frame.
    @Test func colourAndCountChangesAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: CelestialEclipseLabGolden.Frame = try GoldenSupport.frame(name)

        for colourName in CelestialEclipseLabGolden.colourNames {
            let palette: Data = try GoldenSupport.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try CelestialEclipseLabGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = [
            "bodies", "rings", "lenses", "halos", "targets", "matched", "litActions", "actions",
        ]
        for key in countKeys {
            let counts: String? = try CelestialEclipseLabGolden.compare(
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
        let message: String? = try CelestialEclipseLabGolden.compare(try GoldenSupport.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try GoldenSupport.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            var centres: [Any] = try #require(description["bodies"] as? [Any])
            for index in centres.indices {
                if let point = centres[index] as? [Int], point.count == 2 {
                    centres[index] = [point[0] + 1, point[1]]
                    break
                }
            }
            description["bodies"] = centres
        }
        let movedMessage: String? = try CelestialEclipseLabGolden.compare(
            try GoldenSupport.frame("level-021-tier-1"), pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
