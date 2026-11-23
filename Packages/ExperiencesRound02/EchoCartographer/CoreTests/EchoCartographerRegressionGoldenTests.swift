// EchoCartographerRegressionGoldenTests — feature 408 (R02-G11-08) T-R02G1108-004 (FR-R02G1108-003, 004;
// SC-R02G1108-003; clarification Q3). The code-only visual baseline of Echo Cartographer: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0 after the first certified pulses and one marker, then the
// hero frame) in its fixed order with unique names; every frame shows at least one floor, one wall and one marker
// position and its level is not won; deterministic descriptions; every frame's recomputed description against the
// pinned file EchoCartographer/golden-frames.json, which holds exactly the 16 frame names under schema 1; every pinned
// digest against the digest of its pinned description; and the failures the comparison must name, built from the
// pinned manifest in memory (the file is never written by them): a position moved by two 1/8-pixel quanta fails naming
// the frame while one quantum passes, a changed palette colour, a changed count, changed tier detail, a missing frame,
// a renamed or unknown frame, an unknown extra entry in the file (checked by name equality, as `compare` looks up one
// frame at a time), a schema other than 1, an unreadable file and a hand-edited description that kept its old digest.
//
// The pinned file is written only when ECHO_CARTOGRAPHER_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     ECHO_CARTOGRAPHER_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter EchoCartographerRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule). Modelled on
// BackwardsAuroraRegressionGoldenTests (feature 398).
@testable import EchoCartographerCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/EchoCartographer/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

/// The code-only golden frames of Echo Cartographer against the pinned file (see the file header).
@Suite struct EchoCartographerRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["ECHO_CARTOGRAPHER_WRITE_GOLDEN"] == "1" }

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
        return try EchoCartographerGolden.manifest()
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
        let decoded: EchoCartographerGolden.Description = try JSONDecoder().decode(
            EchoCartographerGolden.Description.self, from: data)
        return try EchoCartographerGolden.hash(decoded)
    }

    /// The problem with the set of frame names in the manifest `data` (a missing or an unknown extra entry), or nil
    /// when it is exactly the golden set.
    static func nameProblem(_ data: Data) throws -> String? {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var expected: Set<String> = []
        for frame in EchoCartographerGolden.frames { expected.insert(frame.name) }
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

    /// The manifest `data` with position `index` (0-based) of the list `key` (`floors`, `walls`, `markers`,
    /// `pillars`) of `frame`'s description moved by `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// The manifest `data` with the single position `key` (`entry` or `firstGaugeBar`) of `frame` moved.
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
        for golden in EchoCartographerGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description[key] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        Issue.record("no golden frame has a placed \(key) position")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> EchoCartographerGolden.Frame {
        for frame in EchoCartographerGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The number of on-screen positions in `points`.
    static func placed(_ points: [[Int]?]) -> Int {
        var count: Int = 0
        for point in points where point != nil { count += 1 }
        return count
    }

    /// The 16 frames, their order, names, levels, tiers and time; the hero frame uses the hero scenario's actions.
    @Test func theGoldenSetIsFixed() throws {
        let frames: [EchoCartographerGolden.Frame] = EchoCartographerGolden.frames
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
        #expect(EchoCartographerGolden.levels == levels)
        #expect(EchoCartographerGolden.width == 1_152)
        #expect(EchoCartographerGolden.height == 768)
        #expect(EchoCartographerGolden.schema == 1)
        #expect(EchoCartographerGolden.quantum == 8)
        #expect(EchoCartographerGolden.pulses == 2)
        #expect(EchoCartographerGolden.time == 0)
        let colourNames: [String] = [
            "ground", "floor", "entry", "marker", "wallFace", "wallEdge", "pillar", "ray", "gaugeLit", "gaugeUnlit",
        ]
        #expect(EchoCartographerGolden.colourNames == colourNames)
        var index: Int = 0
        for level in levels {
            let expected: [EchoCartographerAction] = EchoCartographerGolden.frameActions(level: level)
            #expect(!expected.isEmpty, "level \(level) has no actions")
            for tier in 0..<3 {
                let frame: EchoCartographerGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == EchoCartographerGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                index += 1
            }
        }
        let hero: EchoCartographerGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = EchoCartographerExperienceCore.levelNumber(
            forSeed: EchoCartographerExperienceCore.manifestSeed)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        #expect(hero.actions == EchoCartographerExperienceCore.inputActions)
    }

    /// Every frame shows at least one floor, one wall and one marker position, its counts match the snapshot, the
    /// palette and tier detail are the Core's, and its level is not won (replaying its actions leaves the play
    /// playing).
    @Test func everyFrameShowsFloorsWallsAndAMarkerAndIsNotWon() throws {
        for frame in EchoCartographerGolden.frames {
            let level: EchoCartographerLevel = try EchoCartographerExperienceCore.level(number: frame.level)
            var play: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .playing, "\(frame.name) stage \(play.stage)")
            let snapshot: EchoCartographerSceneSnapshot = try EchoCartographerGolden.snapshot(frame)
            #expect(snapshot.stage == .playing, "\(frame.name) snapshot stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            let description: EchoCartographerGolden.Description = try EchoCartographerGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(Self.placed(description.floors) >= 1, "\(frame.name) has no floor on screen")
            #expect(Self.placed(description.walls) >= 1, "\(frame.name) has no wall on screen")
            #expect(Self.placed(description.markers) >= 1, "\(frame.name) has no marker on screen")
            #expect(description.counts.open == snapshot.openCells.count, "\(frame.name) open")
            #expect(description.counts.walls == snapshot.wallCells.count, "\(frame.name) walls")
            #expect(description.counts.markers == snapshot.markers.count, "\(frame.name) markers")
            #expect(description.counts.located == snapshot.located.count, "\(frame.name) located")
            #expect(description.markers.count == snapshot.markers.count, "\(frame.name) marker points")
            #expect(description.pillars.count == snapshot.located.count, "\(frame.name) pillar points")
            #expect(description.entry != nil, "\(frame.name) entry off screen")
            #expect(description.colours.count == 10)
            for name in EchoCartographerGolden.colourNames {
                let expected: EchoCartographerGolden.Colour = EchoCartographerGolden.colour(
                    EchoCartographerGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
            #expect(description.colours["ground"] == EchoCartographerGolden.Colour(r: 0x05, g: 0x07, b: 0x0A))
            #expect(description.colours["wallEdge"] == EchoCartographerGolden.Colour(r: 0x3D, g: 0xF5, b: 0xC4))
            let tier: EchoCartographerTier = EchoCartographerTier.of(frame.tier)
            #expect(description.rings == tier.rings)
            #expect(description.flareTrails == tier.flareTrails)
            #expect(description.glowShells == tier.glowShells)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
        }
    }

    /// Descriptions, digests and the manifest are the same on every run; the three tiers of a level differ.
    @Test func descriptionsAreDeterministic() throws {
        let frames: [EchoCartographerGolden.Frame] = EchoCartographerGolden.frames
        for frame in frames {
            let first: Data = try EchoCartographerGolden.description(frame)
            let second: Data = try EchoCartographerGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try EchoCartographerGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try EchoCartographerGolden.manifest()
        let again: Data = try EchoCartographerGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try EchoCartographerGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    /// Every frame matches the pinned file, which has schema 1 and exactly the 16 frame names; the file is written only
    /// with ECHO_CARTOGRAPHER_WRITE_GOLDEN=1.
    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try EchoCartographerGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not EchoCartographerGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with ECHO_CARTOGRAPHER_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter EchoCartographerRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        let decoded: EchoCartographerGolden.Manifest = try JSONDecoder().decode(
            EchoCartographerGolden.Manifest.self, from: pinned)
        #expect(decoded.schema == 1)
        #expect(decoded.frames.keys.sorted() == Self.expectedNames.sorted())
        #expect(try Self.nameProblem(pinned) == nil)
        for frame in EchoCartographerGolden.frames {
            let result: String? = try EchoCartographerGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without ECHO_CARTOGRAPHER_WRITE_GOLDEN=1")
        }
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in EchoCartographerGolden.frames {
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
        let first: EchoCartographerGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try EchoCartographerGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try EchoCartographerGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try EchoCartographerGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try EchoCartographerGolden.compare(try Self.frame("level-041-tier-1"),
                                                                  pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try EchoCartographerGolden.compare(first, pinned: shortened)
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
        let renamed: String? = try EchoCartographerGolden.compare(try Self.frame("level-061-tier-2"),
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

        // A description whose name differs from its frame (re-digested) is an identity difference.
        let identity: Data = try Self.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try EchoCartographerGolden.compare(try Self.frame("level-081-tier-0"),
                                                                         pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: EchoCartographerGolden.Frame = EchoCartographerGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try EchoCartographerGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// A floor, wall, marker, entry or gauge position moved by two quanta fails naming the frame; one quantum passes; a
    /// removed position is a count difference.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let keys: [String] = ["floors", "walls", "markers"]
        let words: [String] = ["floor", "wall", "marker"]
        for (keyIndex, key) in keys.enumerated() {
            let placed: (frame: String, index: Int) = try Self.firstPlaced(data, key: key)
            let name: String = placed.frame
            let index: Int = placed.index
            let frame: EchoCartographerGolden.Frame = try Self.frame(name)
            let word: String = words[keyIndex]

            let far: String? = try EchoCartographerGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dx: 2))
            #expect(far?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(far ?? "nil")")

            let farY: String? = try EchoCartographerGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dy: -2))
            #expect(farY?.hasPrefix("\(name): \(word) \(index) at ") == true, "\(key): \(farY ?? "nil")")

            let near: String? = try EchoCartographerGolden.compare(
                frame, pinned: try Self.moved(data, frame: name, key: key, index: index, dx: 1, dy: -1))
            #expect(near == nil, "\(key): \(near ?? "")")

            let fewer: Data = try Self.edited(data, frame: name) { description in
                var points: [Any] = try #require(description[key] as? [Any])
                points.removeLast()
                description[key] = points
            }
            let fewerResult: String? = try EchoCartographerGolden.compare(frame, pinned: fewer)
            #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(key): \(fewerResult ?? "nil")")
            #expect(fewerResult?.contains("\(word) points, pinned") == true, "\(key): \(fewerResult ?? "nil")")
        }

        let name: String = "level-021-tier-1"
        let frame: EchoCartographerGolden.Frame = try Self.frame(name)
        let entryFar: String? = try EchoCartographerGolden.compare(
            frame, pinned: try Self.movedSingle(data, frame: name, key: "entry", dx: -2))
        #expect(entryFar?.hasPrefix("\(name): entry at ") == true, "\(entryFar ?? "nil")")
        let entryNear: String? = try EchoCartographerGolden.compare(
            frame, pinned: try Self.movedSingle(data, frame: name, key: "entry", dx: 1, dy: 1))
        #expect(entryNear == nil, "\(entryNear ?? "")")
    }

    /// A changed colour, count or tier detail fails naming the frame.
    @Test func colourCountAndTierChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: EchoCartographerGolden.Frame = try Self.frame(name)

        for colourName in EchoCartographerGolden.colourNames {
            let palette: Data = try Self.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try EchoCartographerGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let countKeys: [String] = ["open", "walls", "markers", "located", "rays", "gaugeLit", "gaugeTotal"]
        for key in countKeys {
            let counts: String? = try EchoCartographerGolden.compare(
                frame, pinned: try Self.shiftedCount(data, frame: name, key: key, by: 1))
            #expect(counts?.hasPrefix("\(name): counts differ") == true, "\(key): \(counts ?? "nil")")
        }

        let glow: String? = try EchoCartographerGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "glowShells", by: 1))
        #expect(glow?.hasPrefix("\(name): tier detail differs") == true, "\(glow ?? "nil")")
        let flagKeys: [String] = ["rings", "flareTrails"]
        for key in flagKeys {
            let flipped: Data = try Self.edited(data, frame: name) { description in
                let value: Bool = try #require(description[key] as? Bool)
                description[key] = !value
            }
            let tier: String? = try EchoCartographerGolden.compare(frame, pinned: flipped)
            #expect(tier?.hasPrefix("\(name): tier detail differs") == true, "\(key): \(tier ?? "nil")")
        }
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try EchoCartographerGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try Self.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            var floors: [Any] = try #require(description["floors"] as? [Any])
            for index in floors.indices {
                if let point = floors[index] as? [Int], point.count == 2 {
                    floors[index] = [point[0] + 1, point[1]]
                    break
                }
            }
            description["floors"] = floors
        }
        let movedMessage: String? = try EchoCartographerGolden.compare(try Self.frame("level-021-tier-1"),
                                                                       pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
