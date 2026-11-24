// MoonlitMechanismRegressionGoldenTests — feature 438 (R02-G14-08) T-R02G1408-004 (FR-R02G1408-003, 004;
// SC-R02G1408-003; clarification Q3). The code-only visual baseline of Moonlit Mechanism: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0, key frame 0 shown, after the stored witness's turns,
// re-seats and lamp steps and before its run, then the hero frame: the hero scenario's certified moves of the level seed
// `manifestSeed` opens) in its fixed order with unique names; every frame shows every cast cell, gear centre, rim check
// point and key-frame card on screen, the lamp, the first moves bar and (with a mesh) the first alignment pip, a partly
// spent moves gauge, and its level is still playing; deterministic descriptions with three distinct tier digests per
// level; every frame's recomputed description against the pinned file MoonlitMechanism/golden-frames.json, which holds
// exactly the 16 frame names under schema 1; every pinned digest against the digest of its pinned description; and the
// failures the comparison must name, built from the pinned manifest in memory (the pinned file is never written by
// them): a position moved by two 1/8-pixel quanta fails naming the frame while one quantum passes, a changed palette
// colour, a changed count, a changed identity, a missing frame, a renamed or unknown frame, an unknown extra entry in
// the file (checked by name equality, as `compare` looks up one frame at a time), a schema other than 1, an unreadable
// file and a hand-edited description that kept its old digest. A position may be null in the schema (a point that does
// not project or lies outside the frame); the helpers that pick a position to move skip nulls. `writeIfRequested` is
// exercised on a temporary file only: it writes nothing without the switch.
//
// The pinned file is written only when MOONLIT_MECHANISM_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     MOONLIT_MECHANISM_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter MoonlitMechanismRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule). Modelled on
// AcousticConstellatorRegressionGoldenTests (feature 428).
@testable import MoonlitMechanismCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/MoonlitMechanism/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

/// The stored witnesses (…/Packages/<package>/MoonlitMechanism/CoreTests/ → docs/games/moonlit-mechanism/levels).
private let goldenWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/moonlit-mechanism/levels", isDirectory: true)

/// The code-only golden frames of Moonlit Mechanism against the pinned file (see the file header).
@Suite struct MoonlitMechanismRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool {
        ProcessInfo.processInfo.environment[MoonlitMechanismGolden.writeSwitch] == "1"
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
        return try MoonlitMechanismGolden.manifest()
    }

    /// The stored witness of level `number`.
    static func witness(_ number: Int) throws -> MoonlitMechanismWitness {
        let digits: String = String(number)
        let name: String = String(repeating: "0", count: max(0, 3 - digits.count)) + digits + ".witness.json"
        let data: Data = try Data(contentsOf: goldenWitnessDirectory.appendingPathComponent(name))
        return try MoonlitMechanismWitness.decode(data)
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
        let decoded: MoonlitMechanismGolden.Description = try JSONDecoder().decode(
            MoonlitMechanismGolden.Description.self, from: data)
        return try MoonlitMechanismGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in MoonlitMechanismGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with position `index` (0-based) of the list `key` (`castCentres`, `gearCentres`,
    /// `rimPoints`, `cardCentres`) of `frame`'s description moved by `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// The manifest `data` with the single position `key` (`firstPip`, `lamp`, `firstMovesBar`) of `frame` moved by
    /// `dx`, `dy` quanta.
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
        for golden in MoonlitMechanismGolden.frames {
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
        for golden in MoonlitMechanismGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            if description[key] is [Int] { return golden.name }
        }
        Issue.record("no golden frame has a placed \(key)")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> MoonlitMechanismGolden.Frame {
        for frame in MoonlitMechanismGolden.frames where frame.name == name { return frame }
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
    /// without the final run; the hero frame uses the hero scenario's actions.
    @Test func theGoldenSetIsFixed() throws {
        let frames: [MoonlitMechanismGolden.Frame] = MoonlitMechanismGolden.frames
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
        #expect(MoonlitMechanismGolden.levels == levels)
        #expect(MoonlitMechanismGolden.width == 1_152)
        #expect(MoonlitMechanismGolden.height == 768)
        #expect(MoonlitMechanismGolden.schema == 1)
        #expect(MoonlitMechanismGolden.quantum == 8)
        #expect(MoonlitMechanismGolden.time == 0)
        #expect(MoonlitMechanismGolden.shownFrame == 0)
        #expect(MoonlitMechanismGolden.writeSwitch == "MOONLIT_MECHANISM_WRITE_GOLDEN")
        let colourNames: [String] = [
            "night", "paper", "ink", "gear", "rim", "blade", "lamp", "cardLit", "cardUnlit", "pip", "movesLit",
            "movesUnlit", "broken",
        ]
        #expect(MoonlitMechanismGolden.colourNames == colourNames)
        var index: Int = 0
        for level in levels {
            let stored: MoonlitMechanismWitness = try Self.witness(level)
            #expect(stored.actions.last == .run, "level \(level) witness does not end with its run")
            let expected: [MoonlitMechanismAction] = Array(stored.actions.dropLast())
            #expect(!expected.isEmpty, "level \(level) has no moves")
            #expect(MoonlitMechanismExperienceCore.certifiedMoves(level) == expected, "level \(level) moves")
            for tier in 0..<3 {
                let frame: MoonlitMechanismGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == MoonlitMechanismGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                #expect(!frame.actions.contains(.run), "\(frame.name) holds a run")
                index += 1
            }
        }
        let hero: MoonlitMechanismGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = MoonlitMechanismExperienceCore.levelNumber(
            forSeed: MoonlitMechanismExperienceCore.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        #expect(hero.actions == MoonlitMechanismExperienceCore.certifiedMoves(heroLevel))
        #expect(hero.actions.count == MoonlitMechanismExperienceCore.heroEntries.count)
        #expect(!hero.actions.isEmpty)
        #expect(!hero.actions.contains(.run))
    }

    /// Every frame shows every cast cell, gear, rim check point and card on screen, the lamp, the first moves bar and
    /// the first pip, its counts match the snapshot, the palette is the Core's, its moves gauge is partly spent and its
    /// level is still playing.
    @Test func everyFrameShowsTheMachineAndGaugesAndIsNotWon() throws {
        typealias G = MoonlitMechanismSceneGeometry
        for frame in MoonlitMechanismGolden.frames {
            let level: MoonlitMechanismLevel = try MoonlitMechanismExperienceCore.level(number: frame.level)
            var play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: MoonlitMechanismSceneSnapshot = try MoonlitMechanismGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            #expect(!snapshot.isWon, "\(frame.name) is won")
            #expect(snapshot.shownFrame == 0, "\(frame.name) shown frame \(snapshot.shownFrame)")
            let description: MoonlitMechanismGolden.Description = try MoonlitMechanismGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
            #expect(description.castCentres.count == snapshot.cast.count, "\(frame.name) cast points")
            #expect(Self.placed(description.castCentres) == snapshot.cast.count, "\(frame.name) cast off screen")
            #expect(snapshot.cast.count >= 1, "\(frame.name) casts no shadow")
            #expect(description.gearCentres.count == snapshot.gears.count, "\(frame.name) gear points")
            #expect(Self.placed(description.gearCentres) == snapshot.gears.count, "\(frame.name) gears off screen")
            #expect(description.rimPoints.count == snapshot.gears.count, "\(frame.name) rim points")
            #expect(Self.placed(description.rimPoints) == snapshot.gears.count, "\(frame.name) rims off screen")
            #expect(description.cardCentres.count == snapshot.keyFrames.count, "\(frame.name) card points")
            #expect(Self.placed(description.cardCentres) == snapshot.keyFrames.count, "\(frame.name) cards off screen")
            #expect(description.lamp != nil, "\(frame.name) lamp off screen")
            #expect(description.firstMovesBar != nil, "\(frame.name) first moves bar off screen")
            #expect((description.firstPip != nil) == (G.pipCount(snapshot) > 0), "\(frame.name) first pip")
            var litCards: Int = 0
            for index in snapshot.keyFrames.indices where G.cardFraction(index, snapshot) > 0 { litCards += 1 }
            var aligned: Int = 0
            for index in 0..<G.pipCount(snapshot) where G.isPipLit(index, snapshot) { aligned += 1 }
            #expect(description.counts.gears == snapshot.gears.count, "\(frame.name) gears")
            #expect(description.counts.cast == snapshot.cast.count, "\(frame.name) cast")
            #expect(description.counts.targets == snapshot.target.count, "\(frame.name) targets")
            #expect(description.counts.missing == snapshot.missingCells.count, "\(frame.name) missing")
            #expect(description.counts.stray == snapshot.strayCells.count, "\(frame.name) stray")
            #expect(description.counts.forbidden == snapshot.forbidden.count, "\(frame.name) forbidden")
            #expect(description.counts.litCards == litCards, "\(frame.name) lit cards")
            #expect(description.counts.alignedPips == aligned, "\(frame.name) aligned pips")
            #expect(description.counts.moves == snapshot.budget, "\(frame.name) moves total")
            #expect(description.counts.litMoves == snapshot.actionsLeft, "\(frame.name) moves lit")
            #expect(description.counts.litMoves < description.counts.moves, "\(frame.name) no spent moves bar")
            #expect(description.counts.litMoves >= 1, "\(frame.name) no moves left for the run")
            #expect(description.colours.count == 13)
            for name in MoonlitMechanismGolden.colourNames {
                let expected: MoonlitMechanismGolden.Colour = MoonlitMechanismGolden.colour(
                    MoonlitMechanismGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
        }
    }

    /// Descriptions, digests and the manifest are the same on every run; the three tiers of a level differ.
    @Test func descriptionsAreDeterministic() throws {
        let frames: [MoonlitMechanismGolden.Frame] = MoonlitMechanismGolden.frames
        for frame in frames {
            let first: Data = try MoonlitMechanismGolden.description(frame)
            let second: Data = try MoonlitMechanismGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try MoonlitMechanismGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try MoonlitMechanismGolden.manifest()
        let again: Data = try MoonlitMechanismGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try MoonlitMechanismGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    /// Every frame matches the pinned file, which has schema 1 and exactly the 16 frame names; the file is written only
    /// with MOONLIT_MECHANISM_WRITE_GOLDEN=1.
    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let written: Bool = try MoonlitMechanismGolden.writeIfRequested(to: goldenFile)
            #expect(written)
            let manifest: Data = try MoonlitMechanismGolden.manifest()
            #expect(try Data(contentsOf: goldenFile) == manifest,
                    "the written file is not MoonlitMechanismGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with MOONLIT_MECHANISM_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter MoonlitMechanismRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        let decoded: MoonlitMechanismGolden.Manifest = try JSONDecoder().decode(
            MoonlitMechanismGolden.Manifest.self, from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == Self.expectedNames.sorted())
        #expect(try Self.nameProblem(pinned) == nil)
        for frame in MoonlitMechanismGolden.frames {
            let result: String? = try MoonlitMechanismGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without MOONLIT_MECHANISM_WRITE_GOLDEN=1")
        }
    }

    /// `writeIfRequested` writes nothing without the switch (absent, empty or not "1") and writes exactly the manifest
    /// with it; exercised on a temporary file, never the pinned one.
    @Test func theFileIsWrittenOnlyWithTheSwitch() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("moonlit-mechanism-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target: URL = directory.appendingPathComponent("golden-frames.json", isDirectory: false)
        let refusals: [[String: String]] = [
            [:], ["MOONLIT_MECHANISM_WRITE_GOLDEN": "0"], ["MOONLIT_MECHANISM_WRITE_GOLDEN": ""],
            ["MOONLIT_MECHANISM_WRITE_GOLDEN": "true"], ["ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN": "1"],
        ]
        for environment in refusals {
            let written: Bool = try MoonlitMechanismGolden.writeIfRequested(to: target, environment: environment)
            #expect(!written, "written with \(environment)")
            #expect(!FileManager.default.fileExists(atPath: target.path), "file created with \(environment)")
        }
        let placeholder: Data = Data("placeholder".utf8)
        try placeholder.write(to: target)
        let refused: Bool = try MoonlitMechanismGolden.writeIfRequested(to: target, environment: [:])
        #expect(!refused)
        #expect(try Data(contentsOf: target) == placeholder, "an existing file was touched without the switch")
        let written: Bool = try MoonlitMechanismGolden.writeIfRequested(
            to: target, environment: ["MOONLIT_MECHANISM_WRITE_GOLDEN": "1"])
        #expect(written)
        #expect(try Data(contentsOf: target) == (try MoonlitMechanismGolden.manifest()))
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in MoonlitMechanismGolden.frames {
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
        let first: MoonlitMechanismGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try MoonlitMechanismGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try MoonlitMechanismGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        let schemas: [Int] = [0, 2]
        for value in schemas {
            var root: [String: Any] = try Self.tree(data)
            root["schema"] = value
            let schema: String? = try MoonlitMechanismGolden.compare(first, pinned: try Self.bytes(root))
            #expect(schema == "golden-frames.json has schema \(value), not 1", "\(schema ?? "nil")")
        }

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try MoonlitMechanismGolden.compare(try Self.frame("level-041-tier-1"),
                                                                  pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try MoonlitMechanismGolden.compare(first, pinned: shortened)
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
        let renamed: String? = try MoonlitMechanismGolden.compare(try Self.frame("level-061-tier-2"),
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
        let identityResult: String? = try MoonlitMechanismGolden.compare(try Self.frame("level-081-tier-0"),
                                                                         pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")
        let identityKeys: [String] = ["level", "tier"]
        for key in identityKeys {
            let shiftedIdentity: String? = try MoonlitMechanismGolden.compare(
                try Self.frame("level-021-tier-0"),
                pinned: try Self.shifted(data, frame: "level-021-tier-0", key: key, by: 1))
            #expect(shiftedIdentity?.hasPrefix("level-021-tier-0: identity differs") == true,
                    "\(key): \(shiftedIdentity ?? "nil")")
        }

        // A changed frame size is named.
        let size: String? = try MoonlitMechanismGolden.compare(
            try Self.frame("level-021-tier-2"), pinned: try Self.shifted(data, frame: "level-021-tier-2", key: "width",
                                                                        by: 1))
        #expect(size == "level-021-tier-2: size differs", "\(size ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: MoonlitMechanismGolden.Frame = MoonlitMechanismGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try MoonlitMechanismGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// A cast centre, gear centre, rim point, card centre, first pip, lamp or first moves bar moved by two quanta fails
    /// naming the frame; one quantum passes; a removed position is named as a different number of points.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let keys: [String] = ["castCentres", "gearCentres", "rimPoints", "cardCentres"]
        let words: [String] = ["cast centre", "gear centre", "rim point", "card centre"]
        for (keyIndex, key) in keys.enumerated() {
            let placed: (frame: String, index: Int) = try Self.firstPlaced(data, key: key)
            let name: String = placed.frame
            let index: Int = placed.index
            let frame: MoonlitMechanismGolden.Frame = try Self.frame(name)
            let word: String = words[keyIndex]

            let far: String? = try MoonlitMechanismGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dx: 2))
            #expect(far?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(far ?? "nil")")

            let farY: String? = try MoonlitMechanismGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dy: -2))
            #expect(farY?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(farY ?? "nil")")

            let near: String? = try MoonlitMechanismGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")

            let fewer: Data = try Self.edited(data, frame: name) { description in
                var points: [Any] = try #require(description[key] as? [Any])
                points.removeLast()
                description[key] = points
            }
            let fewerResult: String? = try MoonlitMechanismGolden.compare(frame, pinned: fewer)
            #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(key): \(fewerResult ?? "nil")")
            #expect(fewerResult?.contains("\(word) points, pinned") == true, "\(key): \(fewerResult ?? "nil")")
        }

        let singles: [String] = ["firstPip", "lamp", "firstMovesBar"]
        let singleWords: [String] = ["first pip", "lamp", "first moves bar"]
        for (keyIndex, key) in singles.enumerated() {
            let name: String = try Self.firstPlacedSingle(data, key: key)
            let frame: MoonlitMechanismGolden.Frame = try Self.frame(name)
            let word: String = singleWords[keyIndex]
            let far: String? = try MoonlitMechanismGolden.compare(
                frame, pinned: try Self.movedSingle(data, frame: name, key: key, dx: -2))
            #expect(far?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(far ?? "nil")")
            let farY: String? = try MoonlitMechanismGolden.compare(
                frame, pinned: try Self.movedSingle(data, frame: name, key: key, dy: 2))
            #expect(farY?.hasPrefix("\(name): \(word) at ") == true, "\(key): \(farY ?? "nil")")
            let near: String? = try MoonlitMechanismGolden.compare(
                frame, pinned: try Self.movedSingle(data, frame: name, key: key, dx: 1, dy: 1))
            #expect(near == nil, "\(key): \(near ?? "")")
        }
    }

    /// A changed colour or count fails naming the frame.
    @Test func colourAndCountChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: MoonlitMechanismGolden.Frame = try Self.frame(name)

        for colourName in MoonlitMechanismGolden.colourNames {
            let palette: Data = try Self.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try MoonlitMechanismGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = ["gears", "cast", "targets", "missing", "stray", "forbidden", "litCards",
                                   "alignedPips", "litMoves", "moves"]
        for key in countKeys {
            let counts: String? = try MoonlitMechanismGolden.compare(
                frame, pinned: try Self.shiftedCount(data, frame: name, key: key, by: 1))
            #expect(counts?.hasPrefix("\(name): counts differ") == true, "\(key): \(counts ?? "nil")")
        }
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            var counts: [String: Any] = try #require(description["counts"] as? [String: Any])
            counts["forbidden"] = 99
            description["counts"] = counts
        }
        let message: String? = try MoonlitMechanismGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try Self.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            var centres: [Any] = try #require(description["castCentres"] as? [Any])
            for index in centres.indices {
                if let point = centres[index] as? [Int], point.count == 2 {
                    centres[index] = [point[0] + 1, point[1]]
                    break
                }
            }
            description["castCentres"] = centres
        }
        let movedMessage: String? = try MoonlitMechanismGolden.compare(try Self.frame("level-021-tier-1"),
                                                                       pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
