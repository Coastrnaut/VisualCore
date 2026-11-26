// ApsidesWorkshopRegressionGoldenTests — feature 478 (R02-G18-08) T-R02G1808-004 (FR-R02G1808-003, 004;
// SC-R02G1808-003; clarification Q3). The code-only visual baseline of Apsides Workshop: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0, each after all certified tunings of its level but not
// the play, shown at tick T / 2; then the hero frame: the level the hero scenario opens, seed `manifestSeed`, after the
// same tunings with the hero tick shown, tier 0) in its fixed order with unique names; every frame is still open, its
// actions gauge is partly spent whenever a tuning was applied and the play then wins it; every frame's counts match the
// snapshot and its palette (18 colours) is the Core's; deterministic descriptions and digests; every frame's recomputed
// description against the pinned file ApsidesWorkshop/golden-frames.json, which holds exactly the 16 frame names under
// schema 1 and equals `manifest()` for the current code; every pinned digest against the digest of its pinned
// description; and the failures the comparison must name, built from the pinned manifest in memory (the pinned file is
// never written by them): the star, the orbiter, a periapsis or apoapsis marker, a planet centre or the first actions
// bar moved by two 1/8-pixel quanta fails naming the frame while one quantum passes, a changed palette colour, a
// changed count, a changed identity, size or tick, a missing frame, a renamed or unknown frame, an unknown extra entry
// in the file (checked by name equality, as `compare` looks up one frame at a time), a schema other than 1, an
// unreadable file and a hand-edited description that kept its old digest. A position may be null in the schema (a
// point that does not project or lies outside the frame); the helpers that pick a position to move skip nulls.
// `writeIfRequested` is exercised on a temporary file only: it writes nothing without the switch and exactly the
// manifest with it.
//
// The pinned file is written only when APSIDES_WORKSHOP_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     APSIDES_WORKSHOP_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter ApsidesWorkshopRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule), and no `try` inside
// `#expect`. Synthetic data only; no wall-clock asserts. Modelled on CelestialEclipseLabRegressionGoldenTests
// (feature 468).
import Foundation
import Testing
import VisualCoreMath
@testable import ApsidesWorkshopCore

/// File-private helpers of the golden tests, kept in one namespace so no name collides with other files of the target.
private enum GoldenSupport {
    /// The pinned golden file, found from this file (…/ApsidesWorkshop/CoreTests/ → ../golden-frames.json).
    static let file: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("golden-frames.json", isDirectory: false)

    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[ApsidesWorkshopGolden.writeSwitch] == "1"
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
        "midnight", "midnightTop", "speck", "wedge", "targetWedge", "compass", "ghost", "glacial", "deepRose", "planet",
        "hazard", "star", "met", "unmet", "actionsLit", "actionsUnlit", "broken", "glow",
    ]

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: file.path) { return try Data(contentsOf: file) }
        return try ApsidesWorkshopGolden.manifest()
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
        let decoded: ApsidesWorkshopGolden.Description = try JSONDecoder().decode(
            ApsidesWorkshopGolden.Description.self, from: data)
        return try ApsidesWorkshopGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in ApsidesWorkshopGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with position `index` (0-based) of the list `planets` of `frame`'s description moved by
    /// `dx`, `dy` quanta.
    static func movedPlanet(_ data: Data, frame: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description["planets"] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description["planets"] = points
        }
    }

    /// The manifest `data` with the single position `key` (`star`, `orbiter`, `periapsis`, `apoapsis`,
    /// `firstActionsBar`) of `frame` moved by `dx`, `dy` quanta.
    static func movedSingle(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// A pinned planet centre: the first golden frame (in the fixed order) whose pinned description has one on screen
    /// (not null), and the 0-based index of that position; nil when no frame has one.
    static func firstPlacedPlanet(_ data: Data) throws -> (frame: String, index: Int)? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in ApsidesWorkshopGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description["planets"] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        return nil
    }

    /// The first golden frame (in the fixed order) whose pinned description has the single position `key` on screen
    /// (not null).
    static func firstPlacedSingle(_ data: Data, key: String) throws -> String {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in ApsidesWorkshopGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> ApsidesWorkshopGolden.Frame {
        for frame in ApsidesWorkshopGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The number of sectors of `snapshot` with a positive share (the swept-area wedges).
    static func wedgeCount(_ snapshot: ApsidesWorkshopSceneSnapshot) -> Int {
        var count: Int = 0
        for share in snapshot.shares where share > 0 { count += 1 }
        return count
    }

    /// The number of met gauges of `snapshot`.
    static func metCount(_ snapshot: ApsidesWorkshopSceneSnapshot) -> Int {
        var count: Int = 0
        for gauge in snapshot.gauges where gauge.met { count += 1 }
        return count
    }
}

/// The code-only golden frames of Apsides Workshop against the pinned file (see the file header).
@Suite struct ApsidesWorkshopRegressionGoldenTests {
    /// The 16 frames, their order, unique names, levels, tiers, time, tunings and ticks; each level frame applies all
    /// certified tunings of its level at tick T / 2; the hero frame applies the hero level's tunings and shows the hero
    /// tick.
    @Test func theGoldenSetIsFixed() throws {
        typealias Core = ApsidesWorkshopExperienceCore
        let frames: [ApsidesWorkshopGolden.Frame] = ApsidesWorkshopGolden.frames
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
        #expect(ApsidesWorkshopGolden.levels == levels)
        #expect(ApsidesWorkshopGolden.width == 1_152)
        #expect(ApsidesWorkshopGolden.height == 768)
        #expect(ApsidesWorkshopGolden.schema == 1)
        #expect(ApsidesWorkshopGolden.quantum == 8)
        #expect(ApsidesWorkshopGolden.time == 0)
        #expect(ApsidesWorkshopGolden.writeSwitch == "APSIDES_WORKSHOP_WRITE_GOLDEN")
        #expect(ApsidesWorkshopGolden.colourNames == GoldenSupport.colourNames)
        #expect(ApsidesWorkshopGolden.colourNames.count == 18)
        try #require(frames.count == 16)
        var index: Int = 0
        for level in levels {
            let certified: [ApsidesWorkshopAction] = Core.certifiedActions(level)
            #expect(!certified.isEmpty, "level \(level) has no certified plan")
            let tick: Int = try #require(Core.heroTick(level))
            let generated: ApsidesWorkshopLevel = try Core.level(number: level)
            #expect(tick == generated.period / 2, "level \(level) tick \(tick)")
            for tier in 0..<3 {
                let frame: ApsidesWorkshopGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.tick == tick, "\(frame.name) tick \(frame.tick)")
                #expect(frame.name == ApsidesWorkshopGolden.name(level: level, tier: tier))
                #expect(frame.actions == certified, "\(frame.name) actions")
                #expect(!frame.actions.contains(.play), "\(frame.name) applies the play")
                index += 1
            }
        }
        let hero: ApsidesWorkshopGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        let heroCertified: [ApsidesWorkshopAction] = Core.certifiedActions(heroLevel)
        #expect(hero.actions == heroCertified)
        #expect(!hero.actions.contains(.play), "hero applies the play")
        let heroTick: Int = try #require(Core.heroTick(heroLevel))
        #expect(hero.tick == heroTick, "hero tick \(hero.tick)")
        // The hero scenario is the tunings, then one shown tick.
        #expect(Core.heroEntries.count == hero.actions.count + 1)
    }

    /// The shown tick is 0 and no tuning is applied for a level that cannot be generated; otherwise the shown tick is
    /// T / 2 and the tunings are the certified plan's.
    @Test func theShownTickIsHalfThePeriodOrZero() throws {
        let outside: [Int] = [0, 101]
        for number in outside {
            let tick: Int = ApsidesWorkshopGolden.shownTick(number)
            #expect(tick == 0, "level \(number) tick \(tick)")
            #expect(ApsidesWorkshopGolden.openTunings(number).isEmpty, "level \(number) applies a tuning")
        }
        for level in ApsidesWorkshopGolden.levels {
            let certified: [ApsidesWorkshopAction] = ApsidesWorkshopExperienceCore.certifiedActions(level)
            #expect(ApsidesWorkshopGolden.openTunings(level) == certified, "level \(level) open tunings")
            let generated: ApsidesWorkshopLevel = try ApsidesWorkshopExperienceCore.level(number: level)
            let tick: Int = ApsidesWorkshopGolden.shownTick(level)
            #expect(tick == generated.period / 2, "level \(level) tick \(tick)")
            #expect(tick >= 0 && tick < generated.period, "level \(level) tick \(tick) outside the period")
        }
    }

    /// Every frame is still open: stage `playing`, no failure, not won, the actions gauge partly spent whenever a
    /// tuning was applied, and the play then wins it.
    @Test func everyFrameIsOpenAndThePlayWinsIt() throws {
        for frame in ApsidesWorkshopGolden.frames {
            let level: ApsidesWorkshopLevel = try ApsidesWorkshopExperienceCore.level(number: frame.level)
            var play: ApsidesWorkshopPlay = try ApsidesWorkshopExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: ApsidesWorkshopSceneSnapshot = try ApsidesWorkshopGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            #expect(!snapshot.isWon, "\(frame.name) is won")
            #expect(!snapshot.isPreviewing, "\(frame.name) previews an orbit")
            #expect(snapshot.levelNumber == frame.level)
            #expect(snapshot.shownTick == frame.tick, "\(frame.name) shown tick \(snapshot.shownTick)")
            if !frame.actions.isEmpty {
                #expect(snapshot.actionsLeft < snapshot.budget, "\(frame.name) no spent actions bar")
            }
            var finished: ApsidesWorkshopPlay = play
            try finished.apply(.play, expecting: finished.fingerprint)
            #expect(finished.stage == .won, "\(frame.name) the play does not win (\(finished.stage))")
        }
    }

    /// Every frame's description has the frame's identity, size and tick, the star, orbiter and apsis markers on
    /// screen, one position per planet, a first actions bar exactly when the budget is positive, counts that match the
    /// snapshot and the Core's palette.
    @Test func everyFrameDescribesItsSnapshot() throws {
        typealias G = ApsidesWorkshopSceneGeometry
        for frame in ApsidesWorkshopGolden.frames {
            let snapshot: ApsidesWorkshopSceneSnapshot = try ApsidesWorkshopGolden.snapshot(frame)
            let description: ApsidesWorkshopGolden.Description = try ApsidesWorkshopGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            #expect(description.tick == snapshot.shownTick)
            #expect(description.star != nil, "\(frame.name) star off screen")
            #expect(description.orbiter != nil, "\(frame.name) orbiter off screen")
            #expect(description.periapsis != nil, "\(frame.name) periapsis marker off screen")
            #expect(description.apoapsis != nil, "\(frame.name) apoapsis marker off screen")
            #expect(description.planets.count == snapshot.planets.count, "\(frame.name) planet points")
            #expect((description.firstActionsBar == nil) == (snapshot.budget <= 0), "\(frame.name) first actions bar")
            #expect(description.counts.sectors == snapshot.shares.count, "\(frame.name) sectors")
            #expect(description.counts.wedges == GoldenSupport.wedgeCount(snapshot), "\(frame.name) wedges")
            #expect(description.counts.wedges <= description.counts.sectors, "\(frame.name) wedges beyond sectors")
            #expect(description.counts.orbitPoints == snapshot.positions.count, "\(frame.name) orbit points")
            #expect(description.counts.orbitPoints == snapshot.period, "\(frame.name) orbit points per tick")
            #expect(description.counts.planets == snapshot.planets.count, "\(frame.name) planets")
            #expect(description.counts.gauges == snapshot.gauges.count, "\(frame.name) gauges")
            #expect(description.counts.met == GoldenSupport.metCount(snapshot), "\(frame.name) met")
            #expect(description.counts.met <= description.counts.gauges, "\(frame.name) met beyond gauges")
            #expect(description.counts.litActions == G.litActions(snapshot), "\(frame.name) lit actions")
            #expect(description.counts.actions == max(snapshot.budget, 0), "\(frame.name) actions total")
            #expect(description.counts.litActions <= description.counts.actions, "\(frame.name) lit beyond total")
            #expect(description.colours.count == 18)
            for name in ApsidesWorkshopGolden.colourNames {
                let expected: ApsidesWorkshopGolden.Colour = ApsidesWorkshopGolden.colour(
                    ApsidesWorkshopGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run.
    @Test func descriptionsAreDeterministic() throws {
        for frame in ApsidesWorkshopGolden.frames {
            let first: Data = try ApsidesWorkshopGolden.description(frame)
            let second: Data = try ApsidesWorkshopGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try ApsidesWorkshopGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try ApsidesWorkshopGolden.manifest()
        let again: Data = try ApsidesWorkshopGolden.manifest()
        #expect(manifest == again)
    }

    /// Every frame matches the pinned file, which has schema 1, exactly the 16 frame names and equals `manifest()` for
    /// the current code; the file is written only with APSIDES_WORKSHOP_WRITE_GOLDEN=1 (the regeneration hook).
    @Test func everyFrameMatchesThePinnedFile() throws {
        let file: URL = GoldenSupport.file
        let before: Data? = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        if GoldenSupport.writing {
            let written: Bool = try ApsidesWorkshopGolden.writeIfRequested(to: file)
            #expect(written)
            let manifest: Data = try ApsidesWorkshopGolden.manifest()
            let onDisk: Data = try Data(contentsOf: file)
            #expect(onDisk == manifest, "the written file is not ApsidesWorkshopGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            Issue.record("""
                \(file.path) is missing; review the visuals and run with APSIDES_WORKSHOP_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshopRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: file)
        let decoded: ApsidesWorkshopGolden.Manifest = try JSONDecoder().decode(
            ApsidesWorkshopGolden.Manifest.self, from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == GoldenSupport.expectedNames.sorted())
        let nameProblem: String? = try GoldenSupport.nameProblem(pinned)
        #expect(nameProblem == nil, "\(nameProblem ?? "")")
        let current: ApsidesWorkshopGolden.Manifest = try JSONDecoder().decode(
            ApsidesWorkshopGolden.Manifest.self, from: try ApsidesWorkshopGolden.manifest())
        #expect(current == decoded, "golden-frames.json is not manifest() for the current code")
        for frame in ApsidesWorkshopGolden.frames {
            let result: String? = try ApsidesWorkshopGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
            let entry: ApsidesWorkshopGolden.Entry = try #require(decoded.frames[frame.name])
            let recomputed: Data = try ApsidesWorkshopGolden.description(frame)
            let pinnedDescription: Data = try ApsidesWorkshopGolden.encoder.encode(entry.description)
            #expect(recomputed == pinnedDescription, "\(frame.name) description")
            let digest: String = try ApsidesWorkshopGolden.digest(frame)
            #expect(entry.digest == digest, "\(frame.name) digest")
        }
        if !GoldenSupport.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: file)
            #expect(after == before, "golden-frames.json changed without APSIDES_WORKSHOP_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apsides-workshop-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["APSIDES_WORKSHOP_WRITE_GOLDEN": "0"], ["APSIDES_WORKSHOP_WRITE_GOLDEN": ""],
            ["APSIDES_WORKSHOP_WRITE_GOLDEN": "true"], ["CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try ApsidesWorkshopGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let placeholder: Data = Data("placeholder".utf8)
        try placeholder.write(to: target)
        let refused: Bool = try ApsidesWorkshopGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        let untouched: Data = try Data(contentsOf: target)
        #expect(untouched == placeholder, "an existing file was touched without the switch")
        let written: Bool = try ApsidesWorkshopGolden.writeIfRequested(
            to: target, environment: ["APSIDES_WORKSHOP_WRITE_GOLDEN": "1"])
        #expect(written)
        let rewritten: Data = try Data(contentsOf: target)
        let manifest: Data = try ApsidesWorkshopGolden.manifest()
        #expect(rewritten == manifest)
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let root: [String: Any] = try GoldenSupport.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in ApsidesWorkshopGolden.frames {
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
        let first: ApsidesWorkshopGolden.Frame = try GoldenSupport.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try ApsidesWorkshopGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try ApsidesWorkshopGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try GoldenSupport.tree(data)
            root["schema"] = value
            let schema: String? = try ApsidesWorkshopGolden.compare(first, pinned: try GoldenSupport.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try GoldenSupport.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try GoldenSupport.bytes(incomplete)
        let missing: String? = try ApsidesWorkshopGolden.compare(try GoldenSupport.frame("level-041-tier-1"),
                                                                 pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try ApsidesWorkshopGolden.compare(first, pinned: shortened)
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
        let renamed: String? = try ApsidesWorkshopGolden.compare(try GoldenSupport.frame("level-061-tier-2"),
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
        let identityResult: String? = try ApsidesWorkshopGolden.compare(
            try GoldenSupport.frame("level-081-tier-0"), pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try ApsidesWorkshopGolden.compare(
                try GoldenSupport.frame("level-021-tier-0"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let sizeKeys: [String] = ["width", "height", "quantum"]
        for key in sizeKeys {
            let size: String? = try ApsidesWorkshopGolden.compare(
                try GoldenSupport.frame("level-021-tier-2"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-2", key: key, by: 1))
            #expect(size == "level-021-tier-2: size differs", "\(key): \(size ?? "nil")")
        }

        // A changed shown tick is named.
        let tick: String? = try ApsidesWorkshopGolden.compare(
            try GoldenSupport.frame("hero"), pinned: try GoldenSupport.shifted(data, frame: "hero", key: "tick", by: 1))
        #expect(tick?.hasPrefix("hero: tick ") == true, "\(tick ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: ApsidesWorkshopGolden.Frame = ApsidesWorkshopGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [], tick: 0)
        let unknownResult: String? = try ApsidesWorkshopGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// The star, the orbiter, the periapsis and apoapsis markers, a planet centre or the first actions bar moved by two
    /// quanta fails naming the frame; one quantum passes; a removed planet position is named as a different number of
    /// points. Planets are checked when a frame places one.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let singles: [String] = ["star", "orbiter", "periapsis", "apoapsis", "firstActionsBar"]
        let singleWords: [String] = ["star", "orbiter", "periapsis marker", "apoapsis marker", "first actions bar"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try GoldenSupport.firstPlacedSingle(data, key: key)
            let frame: ApsidesWorkshopGolden.Frame = try GoldenSupport.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try ApsidesWorkshopGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try ApsidesWorkshopGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try ApsidesWorkshopGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }

        guard let placed = try GoldenSupport.firstPlacedPlanet(data) else { return }
        let name: String = placed.frame
        let index: Int = placed.index
        let frame: ApsidesWorkshopGolden.Frame = try GoldenSupport.frame(name)

        let far: String? = try ApsidesWorkshopGolden.compare(
            frame, pinned: try GoldenSupport.movedPlanet(data, frame: name, index: index, dx: 2))
        #expect(far?.hasPrefix("\(name): planet \(index) at ") == true, "\(far ?? "nil")")

        let farY: String? = try ApsidesWorkshopGolden.compare(
            frame, pinned: try GoldenSupport.movedPlanet(data, frame: name, index: index, dy: -2))
        #expect(farY?.hasPrefix("\(name): planet \(index) at ") == true, "\(farY ?? "nil")")

        let near: String? = try ApsidesWorkshopGolden.compare(
            frame, pinned: try GoldenSupport.movedPlanet(data, frame: name, index: index, dx: 1, dy: 1))
        #expect(near == nil, "\(near ?? "")")

        let fewer: Data = try GoldenSupport.edited(data, frame: name) { description in
            var points: [Any] = try #require(description["planets"] as? [Any])
            points.removeLast()
            description["planets"] = points
        }
        let fewerResult: String? = try ApsidesWorkshopGolden.compare(frame, pinned: fewer)
        #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(fewerResult ?? "nil")")
        #expect(fewerResult?.contains("planet points, pinned") == true, "\(fewerResult ?? "nil")")
    }

    /// A changed colour or count fails naming the frame.
    @Test func colourAndCountChangesAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: ApsidesWorkshopGolden.Frame = try GoldenSupport.frame(name)

        for colourName in ApsidesWorkshopGolden.colourNames {
            let palette: Data = try GoldenSupport.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try ApsidesWorkshopGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = [
            "sectors", "wedges", "orbitPoints", "planets", "gauges", "met", "litActions", "actions",
        ]
        for key in countKeys {
            let counts: String? = try ApsidesWorkshopGolden.compare(
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
        let message: String? = try ApsidesWorkshopGolden.compare(try GoldenSupport.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try GoldenSupport.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            if let point = description["orbiter"] as? [Int], point.count == 2 {
                description["orbiter"] = [point[0] + 1, point[1]]
            } else {
                description["orbiter"] = [0, 0]
            }
        }
        let movedMessage: String? = try ApsidesWorkshopGolden.compare(
            try GoldenSupport.frame("level-021-tier-1"), pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
