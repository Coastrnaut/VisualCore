// BackwardsAuroraRegressionGoldenTests — feature 398 (R02-G10-08) T-R02G1008-004 (FR-R02G1008-003, 004;
// SC-R02G1008-003; clarification Q3). The code-only visual baseline of Backwards Aurora: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0 after the first min(smallest − 1, 2) certified
// reversals, then the hero frame) in its fixed order with unique names; every frame describes every ribbon sample point
// in wave order and every checkpoint ring centre in checkpoint order, the kink count, the tear seam, the reversals spent
// and the budget, the ten palette colours and the tier's detail, with the level not won; deterministic descriptions;
// every frame's recomputed description against the pinned file BackwardsAurora/golden-frames.json; every pinned digest
// against the digest of its pinned description; and the failures the comparison must name, built from the pinned
// manifest in memory (the file is never written by them): a sample point or a ring centre moved by two 1/8-pixel quanta
// fails naming the frame while one quantum passes, a changed palette colour, a changed kink count, tear, reversals spent
// or budget, changed tier detail, a missing frame, a renamed or unknown frame, a schema other than 1, an unreadable file
// and a hand-edited description that kept its old digest.
//
// The pinned file is written only when BACKWARDS_AURORA_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     BACKWARDS_AURORA_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter BackwardsAuroraRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule). Modelled on
// NocturneGardenRegressionGoldenTests (feature 388).
@testable import BackwardsAuroraCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/BackwardsAurora/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

/// The code-only golden frames of Backwards Aurora against the pinned file (see the file header).
@Suite struct BackwardsAuroraRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["BACKWARDS_AURORA_WRITE_GOLDEN"] == "1" }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try BackwardsAuroraGolden.manifest()
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
        let decoded: BackwardsAuroraGolden.Description = try JSONDecoder().decode(
            BackwardsAuroraGolden.Description.self, from: data)
        return try BackwardsAuroraGolden.hash(decoded)
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

    /// `point` (a JSON position `[x, y]`) moved by `dx`, `dy` quanta.
    static func movedPoint(_ point: Any?, dx: Int, dy: Int) throws -> [Int] {
        let position: [Int] = try #require(point as? [Int])
        try #require(position.count == 2)
        return [position[0] + dx, position[1] + dy]
    }

    /// The manifest `data` with position `index` (0-based) of the list `key` (`samples` or `rings`) of `frame`'s
    /// description moved by `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, key: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var points: [Any] = try #require(description[key] as? [Any])
            points[index] = try movedPoint(points[index], dx: dx, dy: dy)
            description[key] = points
        }
    }

    /// A pinned position in the list `key` (`samples` or `rings`): the first golden frame (in the fixed order) whose
    /// pinned description has one on screen, and the 0-based index of that position.
    static func firstPlaced(_ data: Data, key: String) throws -> (frame: String, index: Int) {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in BackwardsAuroraGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let points: [Any] = try #require(description[key] as? [Any])
            for (index, item) in points.enumerated() where item is [Int] { return (golden.name, index) }
        }
        Issue.record("no golden frame has a placed \(key) position")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> BackwardsAuroraGolden.Frame {
        for frame in BackwardsAuroraGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The 16 frames, their order, names, levels, tiers, time and certified-prefix actions; the hero frame is the hero
    /// scenario's first reversal.
    @Test func theGoldenSetIsFixed() throws {
        let frames: [BackwardsAuroraGolden.Frame] = BackwardsAuroraGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(BackwardsAuroraGolden.levels == levels)
        #expect(BackwardsAuroraGolden.width == 1_152)
        #expect(BackwardsAuroraGolden.height == 768)
        #expect(BackwardsAuroraGolden.schema == 1)
        #expect(BackwardsAuroraGolden.quantum == 8)
        #expect(BackwardsAuroraGolden.reversals == 2)
        #expect(BackwardsAuroraGolden.time == 0)
        #expect(BackwardsAuroraGolden.section == 0...1)
        let colourNames: [String] = [
            "ground", "band", "ribbon", "ghost", "ring", "matched", "kink", "tear", "spent", "unspent",
        ]
        #expect(BackwardsAuroraGolden.colourNames == colourNames)
        let expectedNames: [String] = [
            "level-001-tier-0", "level-001-tier-1", "level-001-tier-2",
            "level-021-tier-0", "level-021-tier-1", "level-021-tier-2",
            "level-041-tier-0", "level-041-tier-1", "level-041-tier-2",
            "level-061-tier-0", "level-061-tier-1", "level-061-tier-2",
            "level-081-tier-0", "level-081-tier-1", "level-081-tier-2",
            "hero",
        ]
        var actualNames: [String] = []
        for frame in frames { actualNames.append(frame.name) }
        #expect(actualNames == expectedNames)
        var index: Int = 0
        for level in levels {
            // The first min(smallest − 1, 2) certified reversals, so the level is never won.
            let generated: BackwardsAuroraGenerated = try BackwardsAuroraExperienceCore.generated(number: level)
            let solution: [BackwardsAuroraAction] = generated.solution.actions
            #expect(solution.count == generated.solution.smallest, "level \(level) solution length")
            #expect(BackwardsAuroraExperienceCore.certifiedActions(level) == solution, "level \(level) certified")
            let count: Int = max(0, min(generated.solution.smallest - 1, 2))
            let expected: [BackwardsAuroraAction] = Array(solution.prefix(count))
            for tier in 0..<3 {
                let frame: BackwardsAuroraGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == BackwardsAuroraGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                index += 1
            }
        }
        let hero: BackwardsAuroraGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = BackwardsAuroraExperienceCore.levelNumber(
            forSeed: BackwardsAuroraExperienceCore.manifestSeed)
        #expect(heroLevel == 1)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        // The hero frame is the hero scenario's first reversal: the first neutral reversal of the opening level.
        let inputActions: [BackwardsAuroraAction] = BackwardsAuroraExperienceCore.inputActions
        #expect(inputActions.count == 2)
        let firstInput: BackwardsAuroraAction = try #require(inputActions.first)
        #expect(hero.actions == [firstInput])
        let heroSnapshot: BackwardsAuroraSceneSnapshot = try BackwardsAuroraGolden.snapshot(hero)
        let openingSnapshot: BackwardsAuroraSceneSnapshot = try BackwardsAuroraGolden.snapshot(
            BackwardsAuroraGolden.Frame(name: "opening", level: heroLevel, tier: 0, time: 0, actions: []))
        #expect(heroSnapshot != openingSnapshot)
        #expect(heroSnapshot.spent == 1)
        #expect(heroSnapshot.stage == .playing)
    }

    /// Every frame's description: sample points, ring centres, kinks, tear, reversals spent, budget, palette, tier
    /// detail, size; the level not won.
    @Test func everyFrameDescribesWaveRingsKinksGaugeAndPalette() throws {
        for frame in BackwardsAuroraGolden.frames {
            let snapshot: BackwardsAuroraSceneSnapshot = try BackwardsAuroraGolden.snapshot(frame)
            let description: BackwardsAuroraGolden.Description = try BackwardsAuroraGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(snapshot.stage == .playing, "\(frame.name) stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            #expect(snapshot.sectionStart == 0 && snapshot.sectionEnd == 1, "\(frame.name) section")
            // Every sample point in wave order and every ring centre in checkpoint order; the rings are on screen.
            #expect(description.samples.count == snapshot.count, "\(frame.name) samples")
            #expect(description.samples.count > 1, "\(frame.name) has no wave")
            var placedSamples: Int = 0
            for sample in description.samples where sample != nil { placedSamples += 1 }
            #expect(placedSamples > 0, "\(frame.name) has no sample point on screen")
            #expect(description.rings.count == snapshot.checkpoints.count, "\(frame.name) rings")
            for (index, ring) in description.rings.enumerated() {
                #expect(ring != nil, "\(frame.name) checkpoint ring \(index + 1) is off screen")
            }
            // The kernel's kinks, tear and reversal gauge.
            #expect(description.kinks == snapshot.kinks.count, "\(frame.name) kinks")
            #expect(description.tear == snapshot.tear, "\(frame.name) tear")
            #expect(description.spent == snapshot.spent)
            #expect(description.spent == frame.actions.count, "\(frame.name) spent \(description.spent)")
            #expect(description.budget == snapshot.budget)
            #expect(description.budget > description.spent, "\(frame.name) budget")
            // The palette in 8-bit sRGB.
            #expect(description.colours.count == 10)
            for name in BackwardsAuroraGolden.colourNames {
                let expected: BackwardsAuroraGolden.Colour = BackwardsAuroraGolden.colour(
                    BackwardsAuroraGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
            #expect(description.colours["ground"] == BackwardsAuroraGolden.Colour(r: 0x07, g: 0x0B, b: 0x1F))
            #expect(description.colours["ribbon"] == BackwardsAuroraGolden.Colour(r: 0x1F, g: 0xC8, b: 0xD6))
            #expect(description.colours["unspent"] == BackwardsAuroraGolden.Colour(r: 0x2B, g: 0x33, b: 0x52))
            // The tier's detail and the size.
            let tier: BackwardsAuroraTier = BackwardsAuroraTier.of(frame.tier)
            #expect(description.trailingLayers == tier.trailingLayers)
            #expect(description.pulses == tier.pulses)
            #expect(description.glowShells == tier.glowShells)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
        }
    }

    /// Descriptions, digests and the manifest are the same on every run; the three tiers of a level differ.
    @Test func descriptionsAreDeterministic() throws {
        let frames: [BackwardsAuroraGolden.Frame] = BackwardsAuroraGolden.frames
        for frame in frames {
            let first: Data = try BackwardsAuroraGolden.description(frame)
            let second: Data = try BackwardsAuroraGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try BackwardsAuroraGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try BackwardsAuroraGolden.manifest()
        let again: Data = try BackwardsAuroraGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try BackwardsAuroraGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    /// Every frame matches the pinned file; the file is written only with BACKWARDS_AURORA_WRITE_GOLDEN=1.
    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try BackwardsAuroraGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not BackwardsAuroraGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with BACKWARDS_AURORA_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAuroraRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        for frame in BackwardsAuroraGolden.frames {
            let result: String? = try BackwardsAuroraGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without BACKWARDS_AURORA_WRITE_GOLDEN=1")
        }
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in BackwardsAuroraGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            #expect(pinnedDigest == (try Self.digest(of: description)), "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    /// An unreadable file, schema ≠ 1, a missing, renamed or unknown frame and an identity change are named.
    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let first: BackwardsAuroraGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try BackwardsAuroraGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try BackwardsAuroraGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try BackwardsAuroraGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try BackwardsAuroraGolden.compare(try Self.frame("level-041-tier-1"), pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try BackwardsAuroraGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        // A renamed entry: the frame's own name is gone from the file.
        var renamedRoot: [String: Any] = try Self.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamed: String? = try BackwardsAuroraGolden.compare(try Self.frame("level-061-tier-2"),
                                                                 pinned: try Self.bytes(renamedRoot))
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")

        // A description whose name differs from its frame (re-digested) is an identity difference.
        let identity: Data = try Self.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try BackwardsAuroraGolden.compare(try Self.frame("level-081-tier-0"),
                                                                        pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: BackwardsAuroraGolden.Frame = BackwardsAuroraGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try BackwardsAuroraGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// A sample point or a ring centre moved by two quanta fails naming the frame; one quantum passes; a removed sample
    /// or ring is a count difference.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()

        let placed: (frame: String, index: Int) = try Self.firstPlaced(data, key: "samples")
        let name: String = placed.frame
        let sample: Int = placed.index
        let frame: BackwardsAuroraGolden.Frame = try Self.frame(name)

        let far: String? = try BackwardsAuroraGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "samples", index: sample, dx: 2))
        #expect(far?.hasPrefix("\(name): sample \(sample) at ") == true, "\(far ?? "nil")")

        let farY: String? = try BackwardsAuroraGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "samples", index: sample, dy: -2))
        #expect(farY?.hasPrefix("\(name): sample \(sample) at ") == true, "\(farY ?? "nil")")

        let near: String? = try BackwardsAuroraGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "samples", index: sample, dx: 1, dy: -1))
        #expect(near == nil, "\(near ?? "")")

        let ringPlaced: (frame: String, index: Int) = try Self.firstPlaced(data, key: "rings")
        let ringName: String = ringPlaced.frame
        let ring: Int = ringPlaced.index
        let ringFrame: BackwardsAuroraGolden.Frame = try Self.frame(ringName)

        let farRing: String? = try BackwardsAuroraGolden.compare(
            ringFrame, pinned: try Self.moved(data, frame: ringName, key: "rings", index: ring, dy: 2))
        #expect(farRing?.hasPrefix("\(ringName): checkpoint ring \(ring + 1) at ") == true, "\(farRing ?? "nil")")

        let nearRing: String? = try BackwardsAuroraGolden.compare(
            ringFrame, pinned: try Self.moved(data, frame: ringName, key: "rings", index: ring, dx: -1, dy: 1))
        #expect(nearRing == nil, "\(nearRing ?? "")")

        // A sample point or a ring removed from the description is a count difference.
        let fewer: Data = try Self.edited(data, frame: name) { description in
            var samples: [Any] = try #require(description["samples"] as? [Any])
            samples.removeLast()
            description["samples"] = samples
        }
        let fewerResult: String? = try BackwardsAuroraGolden.compare(frame, pinned: fewer)
        #expect(fewerResult?.hasPrefix("\(name): ") == true, "\(fewerResult ?? "nil")")
        #expect(fewerResult?.contains("samples, pinned") == true, "\(fewerResult ?? "nil")")

        let fewerRings: Data = try Self.edited(data, frame: ringName) { description in
            var rings: [Any] = try #require(description["rings"] as? [Any])
            rings.removeLast()
            description["rings"] = rings
        }
        let fewerRingsResult: String? = try BackwardsAuroraGolden.compare(ringFrame, pinned: fewerRings)
        #expect(fewerRingsResult?.hasPrefix("\(ringName): ") == true, "\(fewerRingsResult ?? "nil")")
        #expect(fewerRingsResult?.contains("rings, pinned") == true, "\(fewerRingsResult ?? "nil")")
    }

    /// A changed colour, kink count, tear, reversals spent, budget or tier detail fails naming the frame.
    @Test func colourCountAndTierChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: BackwardsAuroraGolden.Frame = try Self.frame(name)

        for colourName in BackwardsAuroraGolden.colourNames {
            let palette: Data = try Self.edited(data, frame: name) { description in
                var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
                var colour: [String: Any] = try #require(colours[colourName] as? [String: Any])
                let g: Int = try #require(colour["g"] as? Int)
                colour["g"] = g == 255 ? 254 : g + 1
                colours[colourName] = colour
                description["colours"] = colours
            }
            let paletteResult: String? = try BackwardsAuroraGolden.compare(frame, pinned: palette)
            #expect(paletteResult == "\(name): colour \(colourName) differs", "\(paletteResult ?? "nil")")
        }

        let kinks: String? = try BackwardsAuroraGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "kinks", by: 1))
        #expect(kinks?.hasPrefix("\(name): ") == true, "\(kinks ?? "nil")")
        #expect(kinks?.contains("kinks, pinned") == true, "\(kinks ?? "nil")")

        // A tear where the pinned frame has none (or a different seam where it has one).
        let torn: Data = try Self.edited(data, frame: name) { description in
            if let seam = description["tear"] as? Int {
                description["tear"] = seam + 1
            } else {
                description["tear"] = 0
            }
        }
        let tear: String? = try BackwardsAuroraGolden.compare(frame, pinned: torn)
        #expect(tear?.hasPrefix("\(name): tear ") == true, "\(tear ?? "nil")")

        let spent: String? = try BackwardsAuroraGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "spent", by: 1))
        #expect(spent?.hasPrefix("\(name): reversals spent ") == true, "\(spent ?? "nil")")

        let budget: String? = try BackwardsAuroraGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "budget", by: -1))
        #expect(budget?.hasPrefix("\(name): budget ") == true, "\(budget ?? "nil")")

        let tierKeys: [String] = ["trailingLayers", "pulses", "glowShells"]
        for key in tierKeys {
            let tier: String? = try BackwardsAuroraGolden.compare(
                frame, pinned: try Self.shifted(data, frame: name, key: key, by: 1))
            #expect(tier?.hasPrefix("\(name): tier detail differs") == true, "\(key): \(tier ?? "nil")")
        }
    }

    /// A hand-edited description that kept its old digest is refused, naming the frame.
    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try BackwardsAuroraGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")

        let moved: Data = try Self.edited(data, frame: "level-021-tier-1", redigest: false) { description in
            var samples: [Any] = try #require(description["samples"] as? [Any])
            for index in samples.indices {
                if let point = samples[index] as? [Int], point.count == 2 {
                    samples[index] = [point[0] + 1, point[1]]
                    break
                }
            }
            description["samples"] = samples
        }
        let movedMessage: String? = try BackwardsAuroraGolden.compare(try Self.frame("level-021-tier-1"),
                                                                      pinned: moved)
        #expect(movedMessage
            == "golden-frames.json entry level-021-tier-1: the digest does not match its description",
                "\(movedMessage ?? "nil")")
    }
}
