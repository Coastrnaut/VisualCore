// AcousticConstellatorRegressionGoldenTests — feature 428 (R02-G13-08) T-R02G1308-004 (FR-R02G1308-003, 004;
// SC-R02G1308-003; clarification Q3). The code-only visual baseline of Acoustic Constellator: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0 after the stored witness's links and nudges and before its
// listen, then the hero frame: the hero scenario's certified moves of the level seed `manifestSeed` opens) in its fixed
// order with unique names; every frame shows every star and every link on screen, the first coherence bar, the first
// moves bar and a partly spent moves gauge, and its level is still playing; deterministic descriptions with three
// distinct tier digests per level; every frame's recomputed description against the pinned file
// AcousticConstellator/golden-frames.json, which holds exactly the 16 frame names under schema 1; every pinned digest
// against the digest of its pinned description; and the failures the comparison must name, built from the pinned
// manifest in memory (the pinned file is never written by them): a position moved by two 1/8-pixel quanta fails naming
// the frame while one quantum passes, a changed palette colour, a changed count, a changed identity, a missing frame, a
// renamed or unknown frame, an unknown extra entry in the file (checked by name equality, as `compare` looks up one
// frame at a time), a schema other than 1, an unreadable file and a hand-edited description that kept its old digest.
// `writeIfRequested` is exercised on a temporary file only: it writes nothing without the switch.
//
// The pinned file is written only when ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed
// visual change:
//     ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter AcousticConstellatorRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule). Modelled on
// HarmonicBridgesRegressionGoldenTests (feature 418).
@testable import AcousticConstellatorCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/AcousticConstellator/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

/// The stored witnesses (…/Packages/<package>/AcousticConstellator/CoreTests/ → docs/games/acoustic-constellator/levels).
private let goldenWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/acoustic-constellator/levels", isDirectory: true)

/// The code-only golden frames of Acoustic Constellator against the pinned file (see the file header).
@Suite struct AcousticConstellatorRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[AcousticConstellatorGolden.writeSwitch] == "1"
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
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try AcousticConstellatorGolden.manifest()
    }

    /// The stored witness of level `number`.
    static func witness(_ number: Int) throws -> AcousticConstellatorWitness {
        let digits: String = String(number)
        let name: String = String(repeating: "0", count: max(0, 3 - digits.count)) + digits + ".witness.json"
        let data: Data = try Data(contentsOf: goldenWitnessDirectory.appendingPathComponent(name))
        return try AcousticConstellatorWitness.decode(data)
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
        let decoded: AcousticConstellatorGolden.Description = try JSONDecoder().decode(
            AcousticConstellatorGolden.Description.self, from: data)
        return try AcousticConstellatorGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in AcousticConstellatorGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with position `index` (0-based) of the list `key` (`starCentres`, `linkCheckPoints`) of
    /// `frame`'s description moved by `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// The manifest `data` with the single position `key` (`firstCoherenceBar`, `firstHoldPip`, `firstMovesBar`) of
    /// `frame` moved by `dx`, `dy` quanta.
    static func movedSingle(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// A pinned position in the list `key`: the first golden frame (in the fixed order) whose pinned description has
    /// one on screen, and the 0-based index of that position.
    static func firstPlaced(_ data: Data, key: String) throws -> (frame: String, index: Int) {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in AcousticConstellatorGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description[key] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        Issue.record("no golden frame has a placed \(key) position")
        throw CancellationError()
    }

    /// The first golden frame (in the fixed order) whose pinned description has the single position `key` on screen.
    static func firstPlacedSingle(_ data: Data, key: String) throws -> String {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in AcousticConstellatorGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> AcousticConstellatorGolden.Frame {
        for frame in AcousticConstellatorGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The number of on-screen positions in `points`.
    static func placed(_ points: [[Int]?]) -> Int {
        var count: Int = 0
        for point in points where point != nil { count += 1 }
        return count
    }

    /// The 16 frames, their order, names, levels, tiers and time; each level frame applies its stored witness's actions
    /// without the final listen; the hero frame uses the hero scenario's actions.
    @Test func theGoldenSetIsFixed() throws {
        let frames: [AcousticConstellatorGolden.Frame] = AcousticConstellatorGolden.frames
        #expect(frames.count == 16)
        var actualNames: [String] = []
        var names: Set<String> = []
        for frame in frames {
            actualNames.append(frame.name)
            names.insert(frame.name)
        }
        #expect(names.count == 16)
        #expect(actualNames == Self.expectedNames)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(AcousticConstellatorGolden.levels == levels)
        #expect(AcousticConstellatorGolden.width == 1_152)
        #expect(AcousticConstellatorGolden.height == 768)
        #expect(AcousticConstellatorGolden.schema == 1)
        #expect(AcousticConstellatorGolden.quantum == 8)
        #expect(AcousticConstellatorGolden.time == 0)
        #expect(AcousticConstellatorGolden.writeSwitch == "ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN")
        let colourNames: [String] = [
            "sky", "star", "hand", "silver", "teal", "guide", "coherenceLit", "coherenceUnlit", "thresholdMark",
            "holdLit", "holdUnlit", "movesLit", "movesUnlit",
        ]
        #expect(AcousticConstellatorGolden.colourNames == colourNames)
        var index: Int = 0
        for level in levels {
            let stored: AcousticConstellatorWitness = try Self.witness(level)
            #expect(stored.actions.last == .listen, "level \(level) witness does not end with its listen")
            let expected: [AcousticConstellatorAction] = Array(stored.actions.dropLast())
            #expect(!expected.isEmpty, "level \(level) has no moves")
            #expect(AcousticConstellatorExperienceCore.certifiedMoves(level) == expected, "level \(level) moves")
            for tier in 0..<3 {
                let frame: AcousticConstellatorGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == AcousticConstellatorGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                #expect(!frame.actions.contains(.listen), "\(frame.name) holds a listen")
                index += 1
            }
        }
        let hero: AcousticConstellatorGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = AcousticConstellatorExperienceCore.levelNumber(
            forSeed: AcousticConstellatorExperienceCore.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        #expect(hero.actions == AcousticConstellatorExperienceCore.certifiedMoves(heroLevel))
        #expect(hero.actions.count == AcousticConstellatorExperienceCore.heroEntries.count)
        #expect(!hero.actions.isEmpty)
        #expect(!hero.actions.contains(.listen))
    }

    /// Every frame shows every star and link on screen, the first coherence bar and the first moves bar, its counts
    /// match the snapshot, the palette is the Core's, its moves gauge is partly spent and its level is still playing.
    @Test func everyFrameShowsStarsLinksAndGaugesAndIsNotWon() throws {
        for frame in AcousticConstellatorGolden.frames {
            let level: AcousticConstellatorLevel = try AcousticConstellatorExperienceCore.level(number: frame.level)
            var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: AcousticConstellatorSceneSnapshot = try AcousticConstellatorGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            #expect(!snapshot.won, "\(frame.name) is won")
            #expect(snapshot.shownTick == 0, "\(frame.name) shown tick \(snapshot.shownTick)")
            let description: AcousticConstellatorGolden.Description = try AcousticConstellatorGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            #expect(Self.placed(description.starCentres) == snapshot.stars.count, "\(frame.name) stars off screen")
            #expect(description.starCentres.count == snapshot.stars.count, "\(frame.name) star points")
            #expect(Self.placed(description.linkCheckPoints) == snapshot.links.count,
                    "\(frame.name) links off screen")
            #expect(description.linkCheckPoints.count == snapshot.links.count, "\(frame.name) link points")
            #expect(snapshot.links.count >= 1, "\(frame.name) has no link")
            #expect(description.firstCoherenceBar != nil, "\(frame.name) first coherence bar off screen")
            #expect(description.firstMovesBar != nil, "\(frame.name) first moves bar off screen")
            #expect((description.firstHoldPip != nil) == (snapshot.hold > 0), "\(frame.name) first hold pip")
            var teal: Int = 0
            for index in snapshot.links.indices where snapshot.isTeal(index, at: 0) { teal += 1 }
            #expect(description.counts.stars == snapshot.stars.count, "\(frame.name) stars")
            #expect(description.counts.links == snapshot.links.count, "\(frame.name) links")
            #expect(description.counts.tealLinks == teal, "\(frame.name) teal links")
            #expect(description.counts.guides == snapshot.unlinkedSymbolPairs.count, "\(frame.name) guides")
            #expect(description.counts.coherenceLit == snapshot.coherenceBars(at: 0), "\(frame.name) coherence")
            #expect(description.counts.holdLit == snapshot.run(at: 0), "\(frame.name) hold")
            #expect(description.counts.movesTotal == snapshot.budget, "\(frame.name) moves total")
            #expect(description.counts.movesLit == snapshot.actionsLeft, "\(frame.name) moves lit")
            #expect(description.counts.movesLit < description.counts.movesTotal, "\(frame.name) no spent moves bar")
            #expect(description.counts.movesLit >= 1, "\(frame.name) no moves left for the listen")
            #expect(description.colours.count == 13)
            for name in AcousticConstellatorGolden.colourNames {
                let expected: AcousticConstellatorGolden.Colour = AcousticConstellatorGolden.colour(
                    AcousticConstellatorGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run; the three tiers of a level differ.
    @Test func descriptionsAreDeterministic() throws {
        let frames: [AcousticConstellatorGolden.Frame] = AcousticConstellatorGolden.frames
        for frame in frames {
            let first: Data = try AcousticConstellatorGolden.description(frame)
            let second: Data = try AcousticConstellatorGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try AcousticConstellatorGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try AcousticConstellatorGolden.manifest()
        let again: Data = try AcousticConstellatorGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try AcousticConstellatorGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    /// Every frame matches the pinned file, which has schema 1 and exactly the 16 frame names; the file is written only
    /// with ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1.
    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let written: Bool = try AcousticConstellatorGolden.writeIfRequested(to: goldenFile)
            #expect(written)
            let manifest: Data = try AcousticConstellatorGolden.manifest()
            #expect(try Data(contentsOf: goldenFile) == manifest,
                    "the written file is not AcousticConstellatorGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter AcousticConstellatorRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        let decoded: AcousticConstellatorGolden.Manifest = try JSONDecoder().decode(
            AcousticConstellatorGolden.Manifest.self, from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == Self.expectedNames.sorted())
        #expect(try Self.nameProblem(pinned) == nil)
        for frame in AcousticConstellatorGolden.frames {
            let result: String? = try AcousticConstellatorGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("acoustic-constellator-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN": "0"], ["ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN": ""],
            ["ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN": "true"], ["HARMONIC_BRIDGES_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try AcousticConstellatorGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let placeholder: Data = Data("placeholder".utf8)
        try placeholder.write(to: target)
        let refused: Bool = try AcousticConstellatorGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        #expect(try Data(contentsOf: target) == placeholder, "an existing file was touched without the switch")
        let written: Bool = try AcousticConstellatorGolden.writeIfRequested(
            to: target, environment: ["ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN": "1"])
        #expect(written)
        #expect(try Data(contentsOf: target) == (try AcousticConstellatorGolden.manifest()))
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in AcousticConstellatorGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            #expect(pinnedDigest == (try Self.digest(of: description)), "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    /// An unreadable file, schema ≠ 1, a missing, renamed, unknown or extra frame and an identity change are named.
    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let first: AcousticConstellatorGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try AcousticConstellatorGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try AcousticConstellatorGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try Self.tree(data)
            root["schema"] = value
            let schema: String? = try AcousticConstellatorGolden.compare(first, pinned: try Self.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try AcousticConstellatorGolden.compare(try Self.frame("level-041-tier-1"),
                                                                      pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try AcousticConstellatorGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")
        #expect(try Self.nameProblem(shortened) == "golden-frames.json has no frame level-041-tier-1")

        // A renamed entry: the frame's own name is gone from the file and an unknown name appears.
        var renamedRoot: [String: Any] = try Self.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamedData: Data = try Self.bytes(renamedRoot)
        let renamed: String? = try AcousticConstellatorGolden.compare(try Self.frame("level-061-tier-2"),
                                                                      pinned: renamedData)
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")
        #expect(try Self.nameProblem(renamedData) == "golden-frames.json has unknown frame level-061-tier-9")

        // An unknown extra entry beside the full set is reported by the name check.
        var extraRoot: [String: Any] = try Self.tree(data)
        var extraFrames: [String: Any] = try #require(extraRoot["frames"] as? [String: Any])
        extraFrames["level-099-tier-0"] = try #require(extraFrames["hero"] as? [String: Any])
        extraRoot["frames"] = extraFrames
        let extraData: Data = try Self.bytes(extraRoot)
        #expect(try Self.nameProblem(extraData) == "golden-frames.json has unknown frame level-099-tier-0")

        // A description whose name, level or tier differs from its frame (re-digested) is an identity difference.
        let identity: Data = try Self.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try AcousticConstellatorGolden.compare(try Self.frame("level-081-tier-0"),
                                                                             pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try AcousticConstellatorGolden.compare(
                try Self.frame("level-021-tier-0"),
                pinned: try Self.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let size: String? = try AcousticConstellatorGolden.compare(
            try Self.frame("level-021-tier-2"), pinned: try Self.shifted(data, frame: "level-021-tier-2", key: "width",
                                                                        by: 1))
        #expect(size == "level-021-tier-2: size differs", "\(size ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: AcousticConstellatorGolden.Frame = AcousticConstellatorGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try AcousticConstellatorGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// A star centre, link check point, first coherence bar, first hold pip or first moves bar moved by two quanta fails
    /// naming the frame; one quantum passes; a removed position is named as a different number of points.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let keys: [String] = ["starCentres", "linkCheckPoints"]
        let words: [String] = ["star centre", "link check point"]
        for (keyIndex, key) in keys.enumerated() {
            let placed: (frame: String, index: Int) = try Self.firstPlaced(data, key: key)
            let name: String = placed.frame
            let index: Int = placed.index
            let frame: AcousticConstellatorGolden.Frame = try Self.frame(name)
            let word: String = words[keyIndex]

            let far: String? = try AcousticConstellatorGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dx: 2))
            #expect(far?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(far ?? "nil")")

            let farY: String? = try AcousticConstellatorGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dy: -2))
            #expect(farY?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(farY ?? "nil")")

            let near: String? = try AcousticConstellatorGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")

            let fewer: Data = try Self.edited(data, frame: name) { description in
                var points: [Any] = try #require(description[key] as? [Any])
                points.removeLast()
                description[key] = points
            }
            let fewerResult: String? = try AcousticConstellatorGolden.compare(frame, pinned: fewer)
            #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(key): \(fewerResult ?? "nil")")
            #expect(fewerResult?.contains("\(word) points, pinned") == true, "\(key): \(fewerResult ?? "nil")")
        }

        let singles: [String] = ["firstCoherenceBar", "firstHoldPip", "firstMovesBar"]
        let singleWords: [String] = ["first coherence bar", "first hold pip", "first moves bar"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try Self.firstPlacedSingle(data, key: key)
            let frame: AcousticConstellatorGolden.Frame = try Self.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try AcousticConstellatorGolden.compare(
                frame, pinned: try Self.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try AcousticConstellatorGolden.compare(
                frame, pinned: try Self.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try AcousticConstellatorGolden.compare(
                frame, pinned: try Self.movedSingle(data, frame: name, key: key, dx: 1, dy: 1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }
    }

    /// A changed colour or count fails naming the frame.
    @Test func colourAndCountChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: AcousticConstellatorGolden.Frame = try Self.frame(name)

        for colourName in AcousticConstellatorGolden.colourNames {
            let palette: Data = try Self.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try AcousticConstellatorGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = ["stars", "links", "tealLinks", "guides", "coherenceLit", "holdLit", "movesLit",
                                   "movesTotal"]
        for key in countKeys {
            let counts: String? = try AcousticConstellatorGolden.compare(
                frame, pinned: try Self.shiftedCount(data, frame: name, key: key, by: 1))
            #expect(counts?.hasPrefix("\(name): counts differ") == true, "\(key): \(counts ?? "nil")")
        }
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            counts["guides"] = 9
            description["counts"] = counts
        }
        let message: String? = try AcousticConstellatorGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try Self.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            var centres: [Any] = try #require(description["starCentres"] as? [Any])
            for index in centres.indices {
                if let point = centres[index] as? [Int], point.count == 2 {
                    centres[index] = [point[0] + 1, point[1]]
                    break
                }
            }
            description["starCentres"] = centres
        }
        let movedMessage: String? = try AcousticConstellatorGolden.compare(try Self.frame("level-021-tier-1"),
                                                                           pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
