// VoxelOrigamiRegressionGoldenTests — feature 448 (R02-G15-08) T-R02G1508-004 (FR-R02G1508-003, 004;
// SC-R02G1508-003; clarification Q3). The code-only visual baseline of Voxel Origami: the fixed golden set of 16 frames
// (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0, each after the certified turns of its level without the last
// with hinge 1 chosen, then the hero frame: the level the hero scenario opens, seed `manifestSeed`, after the same open
// turns with the hinge of the certified last turn chosen, tier 0) in its fixed order with unique names; level frames
// are never won and keep a partly spent moves gauge; every frame shows every cube centre, hinge mark and target
// centre, the first pip and the first moves bar on screen, its counts match the snapshot and its palette is the Core's;
// deterministic descriptions and digests; every frame's recomputed description against the pinned file
// VoxelOrigami/golden-frames.json, which holds exactly the 16 frame names under schema 1 and equals `manifest()` for
// the current code; every pinned digest against the digest of its pinned description; and the failures the comparison
// must name, built from the pinned manifest in memory (the pinned file is never written by them): a position moved by
// two 1/8-pixel quanta fails naming the frame while one quantum passes, a changed palette colour, a changed count, a
// changed identity, a missing frame, a renamed or unknown frame, an unknown extra entry in the file (checked by name
// equality, as `compare` looks up one frame at a time), a schema other than 1, an unreadable file and a hand-edited
// description that kept its old digest. A position may be null in the schema (a point that does not project or lies
// outside the frame); the helpers that pick a position to move skip nulls. `writeIfRequested` is exercised on a
// temporary file only: it writes nothing without the switch and exactly the manifest with it.
//
// The pinned file is written only when VOXEL_ORIGAMI_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     VOXEL_ORIGAMI_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter VoxelOrigamiRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule). Modelled on
// MoonlitMechanismRegressionGoldenTests (feature 438).
import Foundation
import Testing
import VisualCoreMath
@testable import VoxelOrigamiCore

/// File-private helpers of the golden tests, kept in one namespace so no name collides with other files of the target.
private enum GoldenSupport {
    /// The pinned golden file, found from this file (…/VoxelOrigami/CoreTests/ → ../golden-frames.json).
    static let file: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("golden-frames.json", isDirectory: false)

    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[VoxelOrigamiGolden.writeSwitch] == "1"
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

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: file.path) { return try Data(contentsOf: file) }
        return try VoxelOrigamiGolden.manifest()
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
        let decoded: VoxelOrigamiGolden.Description = try JSONDecoder().decode(
            VoxelOrigamiGolden.Description.self, from: data)
        return try VoxelOrigamiGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in VoxelOrigamiGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with position `index` (0-based) of the list `key` (`cubeCentres`, `hingeMarks`,
    /// `targetCentres`) of `frame`'s description moved by `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// The manifest `data` with the single position `key` (`firstPip`, `firstMovesBar`) of `frame` moved by `dx`, `dy`
    /// quanta.
    static func movedSingle(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// A pinned position in the list `key`: the first golden frame (in the fixed order) whose pinned description has
    /// one on screen (not null), and the 0-based index of that position.
    static func firstPlaced(_ data: Data, key: String) throws -> (frame: String, index: Int) {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in VoxelOrigamiGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description[key] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        Issue.record("no golden frame has a placed \(key) position")
        throw CancellationError()
    }

    /// The first golden frame (in the fixed order) whose pinned description has the single position `key` on screen
    /// (not null).
    static func firstPlacedSingle(_ data: Data, key: String) throws -> String {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in VoxelOrigamiGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> VoxelOrigamiGolden.Frame {
        for frame in VoxelOrigamiGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The number of on-screen positions in `points`.
    static func placed(_ points: [[Int]?]) -> Int {
        var count: Int = 0
        for point in points where point != nil { count += 1 }
        return count
    }
}

/// The code-only golden frames of Voxel Origami against the pinned file (see the file header).
@Suite struct VoxelOrigamiRegressionGoldenTests {
    /// The 16 frames, their order, names, levels, tiers, time and hinges; each level frame applies the certified turns
    /// of its level without the last with hinge 1 chosen; the hero frame applies the hero level's open turns and
    /// chooses the hinge of its certified last turn.
    @Test func theGoldenSetIsFixed() throws {
        let frames: [VoxelOrigamiGolden.Frame] = VoxelOrigamiGolden.frames
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
        #expect(VoxelOrigamiGolden.levels == levels)
        #expect(VoxelOrigamiGolden.width == 1_152)
        #expect(VoxelOrigamiGolden.height == 768)
        #expect(VoxelOrigamiGolden.schema == 1)
        #expect(VoxelOrigamiGolden.quantum == 8)
        #expect(VoxelOrigamiGolden.time == 0)
        #expect(VoxelOrigamiGolden.chosenHinge == 1)
        #expect(VoxelOrigamiGolden.writeSwitch == "VOXEL_ORIGAMI_WRITE_GOLDEN")
        let colourNames: [String] = [
            "night", "ivory", "ivoryShade", "target", "targetGlow", "hinge", "hingeChosen", "glyphSolid",
            "glyphHollow", "dots", "coveredLit", "coveredUnlit", "movesLit", "movesUnlit", "broken", "glow",
        ]
        #expect(VoxelOrigamiGolden.colourNames == colourNames)
        var index: Int = 0
        for level in levels {
            let certified: [VoxelOrigamiAction] = VoxelOrigamiExperienceCore.certifiedActions(level)
            #expect(!certified.isEmpty, "level \(level) has no certified plan")
            let expected: [VoxelOrigamiAction] = Array(certified.dropLast())
            for tier in 0..<3 {
                let frame: VoxelOrigamiGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.hinge == 1, "\(frame.name) hinge \(frame.hinge)")
                #expect(frame.name == VoxelOrigamiGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                #expect(frame.actions.count == certified.count - 1, "\(frame.name) applies the last turn")
                index += 1
            }
        }
        let hero: VoxelOrigamiGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = VoxelOrigamiExperienceCore.levelNumber(forSeed: VoxelOrigamiExperienceCore.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        let heroCertified: [VoxelOrigamiAction] = VoxelOrigamiExperienceCore.certifiedActions(heroLevel)
        let last: VoxelOrigamiAction = try #require(heroCertified.last)
        #expect(hero.actions == Array(heroCertified.dropLast()))
        #expect(hero.hinge == VoxelOrigamiExperienceCore.hinge(of: last), "hero hinge \(hero.hinge)")
        // The hero scenario is the open turns, then one hinge choice.
        #expect(VoxelOrigamiExperienceCore.heroEntries.count == hero.actions.count + 1)
    }

    /// Level frames are never won: the play is still in stage `playing` with no failure, the certified last turn would
    /// still complete the shape, and the moves gauge is partly spent (a turn was spent whenever a turn was applied).
    @Test func levelFramesAreOpenAndTheLastTurnCompletesThem() throws {
        for frame in VoxelOrigamiGolden.frames {
            let level: VoxelOrigamiLevel = try VoxelOrigamiExperienceCore.level(number: frame.level)
            var play: VoxelOrigamiPlay = try VoxelOrigamiExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: VoxelOrigamiSceneSnapshot = try VoxelOrigamiGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            #expect(!snapshot.isWon, "\(frame.name) is won")
            #expect(snapshot.chosenHinge == frame.hinge, "\(frame.name) chosen hinge \(snapshot.chosenHinge)")
            #expect(snapshot.levelNumber == frame.level)
            if !frame.actions.isEmpty {
                #expect(snapshot.actionsLeft < snapshot.budget, "\(frame.name) no spent moves bar")
            }
            let certified: [VoxelOrigamiAction] = VoxelOrigamiExperienceCore.certifiedActions(frame.level)
            let last: VoxelOrigamiAction = try #require(certified.last)
            var finished: VoxelOrigamiPlay = play
            try finished.apply(last, expecting: finished.fingerprint)
            #expect(finished.stage == .won, "\(frame.name) the certified last turn does not win (\(finished.stage))")
        }
    }

    /// Every frame shows every cube centre, hinge mark and target centre on screen, the first pip and the first moves
    /// bar, its counts match the snapshot and the palette is the Core's.
    @Test func everyFrameShowsTheFoldAndGauges() throws {
        typealias G = VoxelOrigamiSceneGeometry
        for frame in VoxelOrigamiGolden.frames {
            let snapshot: VoxelOrigamiSceneSnapshot = try VoxelOrigamiGolden.snapshot(frame)
            let description: VoxelOrigamiGolden.Description = try VoxelOrigamiGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            let cubes: Int = snapshot.cubes.count
            #expect(cubes >= 2, "\(frame.name) has \(cubes) cubes")
            #expect(description.cubeCentres.count == cubes, "\(frame.name) cube points")
            #expect(GoldenSupport.placed(description.cubeCentres) == cubes, "\(frame.name) cubes off screen")
            #expect(description.hingeMarks.count == cubes - 1, "\(frame.name) hinge points")
            #expect(GoldenSupport.placed(description.hingeMarks) == cubes - 1, "\(frame.name) hinges off screen")
            #expect(description.targetCentres.count == snapshot.target.count, "\(frame.name) target points")
            #expect(GoldenSupport.placed(description.targetCentres) == snapshot.target.count,
                    "\(frame.name) targets off screen")
            #expect(description.firstPip != nil, "\(frame.name) first pip off screen")
            #expect(description.firstMovesBar != nil, "\(frame.name) first moves bar off screen")
            #expect(description.counts.cubes == cubes, "\(frame.name) cubes")
            #expect(description.counts.hinges == cubes - 1, "\(frame.name) hinges")
            #expect(description.counts.targets == snapshot.target.count, "\(frame.name) targets")
            #expect(description.counts.inPlace == snapshot.report.covered, "\(frame.name) in place")
            #expect(description.counts.inPlace < cubes, "\(frame.name) every cube in place")
            #expect(description.counts.litPips == G.litPips(snapshot), "\(frame.name) lit pips")
            #expect(description.counts.litMoves == G.litMoves(snapshot), "\(frame.name) lit moves")
            #expect(description.counts.moves == snapshot.budget, "\(frame.name) moves total")
            #expect(description.counts.litMoves >= 1, "\(frame.name) no moves left for the last turn")
            #expect(description.colours.count == 16)
            for name in VoxelOrigamiGolden.colourNames {
                let expected: VoxelOrigamiGolden.Colour = VoxelOrigamiGolden.colour(
                    VoxelOrigamiGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run; the three tiers of a level differ in digest.
    @Test func descriptionsAreDeterministic() throws {
        let frames: [VoxelOrigamiGolden.Frame] = VoxelOrigamiGolden.frames
        for frame in frames {
            let first: Data = try VoxelOrigamiGolden.description(frame)
            let second: Data = try VoxelOrigamiGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try VoxelOrigamiGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try VoxelOrigamiGolden.manifest()
        let again: Data = try VoxelOrigamiGolden.manifest()
        #expect(manifest == again)
        for level in VoxelOrigamiGolden.levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try VoxelOrigamiGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    /// Every frame matches the pinned file, which has schema 1, exactly the 16 frame names and equals `manifest()` for
    /// the current code; the file is written only with VOXEL_ORIGAMI_WRITE_GOLDEN=1.
    @Test func everyFrameMatchesThePinnedFile() throws {
        let file: URL = GoldenSupport.file
        let before: Data? = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        if GoldenSupport.writing {
            let written: Bool = try VoxelOrigamiGolden.writeIfRequested(to: file)
            #expect(written)
            let manifest: Data = try VoxelOrigamiGolden.manifest()
            #expect(try Data(contentsOf: file) == manifest, "the written file is not VoxelOrigamiGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            Issue.record("""
                \(file.path) is missing; review the visuals and run with VOXEL_ORIGAMI_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter VoxelOrigamiRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: file)
        let decoded: VoxelOrigamiGolden.Manifest = try JSONDecoder().decode(VoxelOrigamiGolden.Manifest.self,
                                                                             from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == GoldenSupport.expectedNames.sorted())
        #expect(try GoldenSupport.nameProblem(pinned) == nil)
        let current: VoxelOrigamiGolden.Manifest = try JSONDecoder().decode(
            VoxelOrigamiGolden.Manifest.self, from: try VoxelOrigamiGolden.manifest())
        #expect(current == decoded, "golden-frames.json is not manifest() for the current code")
        for frame in VoxelOrigamiGolden.frames {
            let result: String? = try VoxelOrigamiGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
            let entry: VoxelOrigamiGolden.Entry = try #require(decoded.frames[frame.name])
            #expect(entry.digest == (try VoxelOrigamiGolden.digest(frame)), "\(frame.name) digest")
        }
        if !GoldenSupport.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: file)
            #expect(after == before, "golden-frames.json changed without VOXEL_ORIGAMI_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxel-origami-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["VOXEL_ORIGAMI_WRITE_GOLDEN": "0"], ["VOXEL_ORIGAMI_WRITE_GOLDEN": ""],
            ["VOXEL_ORIGAMI_WRITE_GOLDEN": "true"], ["MOONLIT_MECHANISM_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try VoxelOrigamiGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let placeholder: Data = Data("placeholder".utf8)
        try placeholder.write(to: target)
        let refused: Bool = try VoxelOrigamiGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        #expect(try Data(contentsOf: target) == placeholder, "an existing file was touched without the switch")
        let written: Bool = try VoxelOrigamiGolden.writeIfRequested(
            to: target, environment: ["VOXEL_ORIGAMI_WRITE_GOLDEN": "1"])
        #expect(written)
        #expect(try Data(contentsOf: target) == (try VoxelOrigamiGolden.manifest()))
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let root: [String: Any] = try GoldenSupport.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in VoxelOrigamiGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            #expect(pinnedDigest == (try GoldenSupport.digest(of: description)), "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    /// An unreadable file, schema ≠ 1, a missing, renamed, unknown or extra frame and an identity change are named.
    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let first: VoxelOrigamiGolden.Frame = try GoldenSupport.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try VoxelOrigamiGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try VoxelOrigamiGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try GoldenSupport.tree(data)
            root["schema"] = value
            let schema: String? = try VoxelOrigamiGolden.compare(first, pinned: try GoldenSupport.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try GoldenSupport.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try GoldenSupport.bytes(incomplete)
        let missing: String? = try VoxelOrigamiGolden.compare(try GoldenSupport.frame("level-041-tier-1"),
                                                              pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try VoxelOrigamiGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")
        #expect(try GoldenSupport.nameProblem(shortened) == "golden-frames.json has no frame level-041-tier-1")

        // A renamed entry: the frame's own name is gone from the file and an unknown name appears.
        var renamedRoot: [String: Any] = try GoldenSupport.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamedData: Data = try GoldenSupport.bytes(renamedRoot)
        let renamed: String? = try VoxelOrigamiGolden.compare(try GoldenSupport.frame("level-061-tier-2"),
                                                              pinned: renamedData)
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")
        #expect(try GoldenSupport.nameProblem(renamedData) == "golden-frames.json has unknown frame level-061-tier-9")

        // An unknown extra entry beside the full set is reported by the name check.
        var extraRoot: [String: Any] = try GoldenSupport.tree(data)
        var extraFrames: [String: Any] = try #require(extraRoot["frames"] as? [String: Any])
        extraFrames["level-099-tier-0"] = try #require(extraFrames["hero"] as? [String: Any])
        extraRoot["frames"] = extraFrames
        let extraData: Data = try GoldenSupport.bytes(extraRoot)
        #expect(try GoldenSupport.nameProblem(extraData) == "golden-frames.json has unknown frame level-099-tier-0")

        // A description whose name, level or tier differs from its frame (re-digested) is an identity difference.
        let identity: Data = try GoldenSupport.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try VoxelOrigamiGolden.compare(try GoldenSupport.frame("level-081-tier-0"),
                                                                     pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try VoxelOrigamiGolden.compare(
                try GoldenSupport.frame("level-021-tier-0"),
                pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let size: String? = try VoxelOrigamiGolden.compare(
            try GoldenSupport.frame("level-021-tier-2"),
            pinned: try GoldenSupport.shifted(data, frame: "level-021-tier-2", key: "width", by: 1))
        #expect(size == "level-021-tier-2: size differs", "\(size ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: VoxelOrigamiGolden.Frame = VoxelOrigamiGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [], hinge: 1)
        let unknownResult: String? = try VoxelOrigamiGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// A cube centre, hinge mark, target centre, first pip or first moves bar moved by two quanta fails naming the
    /// frame; one quantum passes; a removed position is named as a different number of points.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let keys: [String] = ["cubeCentres", "hingeMarks", "targetCentres"]
        let words: [String] = ["cube centre", "hinge mark", "target centre"]
        for (keyIndex, key) in keys.enumerated() {
            let placed: (frame: String, index: Int) = try GoldenSupport.firstPlaced(data, key: key)
            let name: String = placed.frame
            let index: Int = placed.index
            let frame: VoxelOrigamiGolden.Frame = try GoldenSupport.frame(name)
            let word: String = words[keyIndex]

            let far: String? = try VoxelOrigamiGolden.compare(
                frame, pinned: try GoldenSupport.moved(data, frame: name, key: key, index: index, dx: 2))
            #expect(far?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(far ?? "nil")")

            let farY: String? = try VoxelOrigamiGolden.compare(
                frame, pinned: try GoldenSupport.moved(data, frame: name, key: key, index: index, dy: -2))
            #expect(farY?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(farY ?? "nil")")

            let near: String? = try VoxelOrigamiGolden.compare(
                frame, pinned: try GoldenSupport.moved(data, frame: name, key: key, index: index, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")

            let fewer: Data = try GoldenSupport.edited(data, frame: name) { description in
                var points: [Any] = try #require(description[key] as? [Any])
                points.removeLast()
                description[key] = points
            }
            let fewerResult: String? = try VoxelOrigamiGolden.compare(frame, pinned: fewer)
            #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(key): \(fewerResult ?? "nil")")
            #expect(fewerResult?.contains("\(word) points, pinned") == true, "\(key): \(fewerResult ?? "nil")")
        }

        let singles: [String] = ["firstPip", "firstMovesBar"]
        let singleWords: [String] = ["first pip", "first moves bar"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try GoldenSupport.firstPlacedSingle(data, key: key)
            let frame: VoxelOrigamiGolden.Frame = try GoldenSupport.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try VoxelOrigamiGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try VoxelOrigamiGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try VoxelOrigamiGolden.compare(
                frame, pinned: try GoldenSupport.movedSingle(data, frame: name, key: key, dx: 1, dy: 1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }
    }

    /// A changed colour or count fails naming the frame.
    @Test func colourAndCountChangesAreCaught() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: VoxelOrigamiGolden.Frame = try GoldenSupport.frame(name)

        for colourName in VoxelOrigamiGolden.colourNames {
            let palette: Data = try GoldenSupport.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try VoxelOrigamiGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = ["cubes", "hinges", "targets", "inPlace", "litPips", "litMoves", "moves"]
        for key in countKeys {
            let counts: String? = try VoxelOrigamiGolden.compare(
                frame, pinned: try GoldenSupport.shiftedCount(data, frame: name, key: key, by: 1))
            #expect(counts?.hasPrefix("\(name): counts differ") == true, "\(key): \(counts ?? "nil")")
        }
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try GoldenSupport.pinnedOrCurrent()
        let edited: Data = try GoldenSupport.edited(data, frame: "hero", redigest: false) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            counts["moves"] = 99
            description["counts"] = counts
        }
        let message: String? = try VoxelOrigamiGolden.compare(try GoldenSupport.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try GoldenSupport.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            var centres: [Any] = try #require(description["cubeCentres"] as? [Any])
            for index in centres.indices {
                if let point = centres[index] as? [Int], point.count == 2 {
                    centres[index] = [point[0] + 1, point[1]]
                    break
                }
            }
            description["cubeCentres"] = centres
        }
        let movedMessage: String? = try VoxelOrigamiGolden.compare(try GoldenSupport.frame("level-021-tier-1"),
                                                                   pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
