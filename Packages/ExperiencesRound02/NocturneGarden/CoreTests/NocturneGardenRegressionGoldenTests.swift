// NocturneGardenRegressionGoldenTests — feature 388 (R02-G09-08) T-R02G0908-004 (FR-R02G0908-003, 004;
// SC-R02G0908-003; clarification Q3). The code-only visual baseline of Nocturne Garden: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at time 0 after the first min(smallest − 1, 2) certified moves,
// then the hero frame) in its fixed order with unique names; every frame describes every bloom head centre in canonical
// order and the lantern centre, the shadow cell count, the moves spent and the budget, the nine palette colours and the
// tier's detail, with the level not won; deterministic descriptions; every frame's recomputed description against the
// pinned file NocturneGarden/golden-frames.json; every pinned digest against the digest of its pinned description; and
// the failures the comparison must name, built from the pinned manifest in memory (the file is never written by them):
// a bloom head or the lantern moved by two 1/8-pixel quanta fails naming the frame while one quantum passes, a changed
// palette colour, a changed shadow cell count, move count or budget, changed tier detail, a missing frame, a renamed or
// unknown frame, a schema other than 1, an unreadable file and a hand-edited description that kept its old digest.
//
// The pinned file is written only when NOCTURNE_GARDEN_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     NOCTURNE_GARDEN_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter NocturneGardenRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule).
@testable import NocturneGardenCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/NocturneGarden/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

/// The code-only golden frames of Nocturne Garden against the pinned file (see the file header).
@Suite struct NocturneGardenRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["NOCTURNE_GARDEN_WRITE_GOLDEN"] == "1" }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try NocturneGardenGolden.manifest()
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
        let decoded: NocturneGardenGolden.Description = try JSONDecoder().decode(
            NocturneGardenGolden.Description.self, from: data)
        return try NocturneGardenGolden.hash(decoded)
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

    /// The manifest `data` with the lantern centre of `frame`'s description moved by `dx`, `dy` quanta.
    static func movedLantern(_ data: Data, frame: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description["lantern"] = try movedPoint(description["lantern"], dx: dx, dy: dy)
        }
    }

    /// The manifest `data` with bloom `index`'s head centre (0-based) of `frame`'s description moved by `dx`, `dy`
    /// quanta.
    static func movedBloom(_ data: Data, frame: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var blooms: [Any] = try #require(description["blooms"] as? [Any])
            blooms[index] = try movedPoint(blooms[index], dx: dx, dy: dy)
            description["blooms"] = blooms
        }
    }

    /// A pinned bloom head with a position: the first golden frame (in the fixed order) whose pinned description has
    /// one, and the 0-based index of that bloom.
    static func firstPlacedBloom(_ data: Data) throws -> (frame: String, index: Int) {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for golden in NocturneGardenGolden.frames {
            let entry: [String: Any] = try #require(frames[golden.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let blooms: [Any] = try #require(description["blooms"] as? [Any])
            for (index, item) in blooms.enumerated() where item is [Int] { return (golden.name, index) }
        }
        Issue.record("no golden frame has a placed bloom")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> NocturneGardenGolden.Frame {
        for frame in NocturneGardenGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The 16 frames, their order, names, levels, tiers, time and certified-prefix actions; the hero frame is the hero
    /// scenario's first move.
    @Test func theGoldenSetIsFixed() throws {
        let frames: [NocturneGardenGolden.Frame] = NocturneGardenGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(NocturneGardenGolden.levels == levels)
        #expect(NocturneGardenGolden.width == 1_152)
        #expect(NocturneGardenGolden.height == 768)
        #expect(NocturneGardenGolden.schema == 1)
        #expect(NocturneGardenGolden.quantum == 8)
        #expect(NocturneGardenGolden.moves == 2)
        #expect(NocturneGardenGolden.time == 0)
        let colourNames: [String] = [
            "ground", "mist", "shadow", "gold", "coral", "leak", "lantern", "spent", "unspent",
        ]
        #expect(NocturneGardenGolden.colourNames == colourNames)
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
            // The first min(smallest − 1, 2) certified moves, so the level is never won.
            let generated: NocturneGardenGenerated = try NocturneGardenExperienceCore.generated(number: level)
            let solution: [NocturneGardenAction] = generated.solution.actions
            #expect(solution.count == generated.solution.smallest, "level \(level) solution length")
            #expect(NocturneGardenExperienceCore.certifiedActions(level) == solution, "level \(level) certified")
            let count: Int = max(0, min(generated.solution.smallest - 1, 2))
            let expected: [NocturneGardenAction] = Array(solution.prefix(count))
            for tier in 0..<3 {
                let frame: NocturneGardenGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == NocturneGardenGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                index += 1
            }
        }
        let hero: NocturneGardenGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        let heroLevel: Int = NocturneGardenExperienceCore.levelNumber(
            forSeed: NocturneGardenExperienceCore.manifestSeed)
        #expect(heroLevel == 1)
        #expect(hero.level == heroLevel)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        // The hero frame is the hero scenario's first move: the neutral plant.
        let inputActions: [NocturneGardenAction] = NocturneGardenExperienceCore.inputActions
        let firstInput: NocturneGardenAction = try #require(inputActions.first)
        #expect(NocturneGardenExperienceCore.heroEntries.count == 1)
        #expect(NocturneGardenExperienceCore.heroEntries.first?.action
            == NocturneGardenExperienceCore.scripted(firstInput))
        #expect(hero.actions == [firstInput])
        let heroSnapshot: NocturneGardenSceneSnapshot = try NocturneGardenGolden.snapshot(hero)
        let openingSnapshot: NocturneGardenSceneSnapshot = try NocturneGardenGolden.snapshot(
            NocturneGardenGolden.Frame(name: "opening", level: heroLevel, tier: 0, time: 0, actions: []))
        #expect(heroSnapshot != openingSnapshot)
        #expect(heroSnapshot.moves == 1)
        #expect(heroSnapshot.blooms.count == 1)
    }

    /// Every frame's description: bloom heads and lantern on screen, shadow cells, moves, budget, palette, tier detail,
    /// size; the level not won.
    @Test func everyFrameDescribesBloomsLanternShadowMovesAndPalette() throws {
        for frame in NocturneGardenGolden.frames {
            let snapshot: NocturneGardenSceneSnapshot = try NocturneGardenGolden.snapshot(frame)
            let description: NocturneGardenGolden.Description = try NocturneGardenGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(snapshot.stage == .playing, "\(frame.name) stage \(snapshot.stage)")
            #expect(snapshot.failure == nil, "\(frame.name) failed")
            // Every bloom head centre in canonical order, on screen; the lantern on screen.
            #expect(description.blooms.count == snapshot.blooms.count, "\(frame.name) blooms")
            for (index, bloom) in description.blooms.enumerated() {
                #expect(bloom != nil, "\(frame.name) bloom \(index + 1) is off screen")
            }
            #expect(description.lantern != nil, "\(frame.name) lantern is off screen")
            // The kernel's shadow and the move gauge.
            #expect(description.shadowCells == snapshot.shadow.count, "\(frame.name) shadow cells")
            #expect(description.moves == snapshot.moves)
            #expect(description.moves == frame.actions.count, "\(frame.name) moves \(description.moves)")
            #expect(description.budget == snapshot.budget)
            #expect(description.budget > description.moves, "\(frame.name) budget")
            // The palette in 8-bit sRGB.
            #expect(description.colours.count == 9)
            for name in NocturneGardenGolden.colourNames {
                let expected: NocturneGardenGolden.Colour = NocturneGardenGolden.colour(
                    NocturneGardenGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
            #expect(description.colours["gold"] == NocturneGardenGolden.Colour(r: 0xE8, g: 0xC8, b: 0x72))
            #expect(description.colours["unspent"] == NocturneGardenGolden.Colour(r: 0x3A, g: 0x45, b: 0x58))
            // The tier's detail and the size.
            let tier: NocturneGardenTier = NocturneGardenTier.of(frame.tier)
            #expect(description.mistLayers == tier.mistLayers)
            #expect(description.stemDepth == tier.stemDepth)
            #expect(description.featherHundredths == Int((tier.feather * 100).rounded()))
            #expect(description.glowShells == tier.glowShells)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
        }
    }

    /// Descriptions, digests and the manifest are the same on every run; the three tiers of a level differ.
    @Test func descriptionsAreDeterministic() throws {
        let frames: [NocturneGardenGolden.Frame] = NocturneGardenGolden.frames
        for frame in frames {
            let first: Data = try NocturneGardenGolden.description(frame)
            let second: Data = try NocturneGardenGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try NocturneGardenGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try NocturneGardenGolden.manifest()
        let again: Data = try NocturneGardenGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try NocturneGardenGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    /// Every frame matches the pinned file; the file is written only with NOCTURNE_GARDEN_WRITE_GOLDEN=1.
    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try NocturneGardenGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not NocturneGardenGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with NOCTURNE_GARDEN_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter NocturneGardenRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        for frame in NocturneGardenGolden.frames {
            let result: String? = try NocturneGardenGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without NOCTURNE_GARDEN_WRITE_GOLDEN=1")
        }
    }

    /// Each pinned digest is the digest of its pinned description.
    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in NocturneGardenGolden.frames {
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
        let first: NocturneGardenGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try NocturneGardenGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try NocturneGardenGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try NocturneGardenGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try NocturneGardenGolden.compare(try Self.frame("level-041-tier-1"), pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try NocturneGardenGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        // A renamed entry: the frame's own name is gone from the file.
        var renamedRoot: [String: Any] = try Self.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamed: String? = try NocturneGardenGolden.compare(try Self.frame("level-061-tier-2"),
                                                                pinned: try Self.bytes(renamedRoot))
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")

        // A description whose name differs from its frame (re-digested) is an identity difference.
        let identity: Data = try Self.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try NocturneGardenGolden.compare(try Self.frame("level-081-tier-0"),
                                                                       pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: NocturneGardenGolden.Frame = NocturneGardenGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try NocturneGardenGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    /// A bloom head or the lantern moved by two quanta fails naming the frame; one quantum passes; a removed bloom is a
    /// count difference.
    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let placed: (frame: String, index: Int) = try Self.firstPlacedBloom(data)
        let name: String = placed.frame
        let bloom: Int = placed.index
        let frame: NocturneGardenGolden.Frame = try Self.frame(name)

        let far: String? = try NocturneGardenGolden.compare(
            frame, pinned: try Self.movedBloom(data, frame: name, index: bloom, dx: 2))
        #expect(far?.hasPrefix("\(name): bloom \(bloom + 1) head centre at ") == true, "\(far ?? "nil")")

        let farY: String? = try NocturneGardenGolden.compare(
            frame, pinned: try Self.movedBloom(data, frame: name, index: bloom, dy: -2))
        #expect(farY?.hasPrefix("\(name): bloom \(bloom + 1) head centre at ") == true, "\(farY ?? "nil")")

        let near: String? = try NocturneGardenGolden.compare(
            frame, pinned: try Self.movedBloom(data, frame: name, index: bloom, dx: 1, dy: -1))
        #expect(near == nil, "\(near ?? "")")

        let lanternName: String = "level-021-tier-1"
        let lanternFrame: NocturneGardenGolden.Frame = try Self.frame(lanternName)
        let lantern: String? = try NocturneGardenGolden.compare(
            lanternFrame, pinned: try Self.movedLantern(data, frame: lanternName, dy: 2))
        #expect(lantern?.hasPrefix("\(lanternName): lantern centre at ") == true, "\(lantern ?? "nil")")

        let nearLantern: String? = try NocturneGardenGolden.compare(
            lanternFrame, pinned: try Self.movedLantern(data, frame: lanternName, dx: -1))
        #expect(nearLantern == nil, "\(nearLantern ?? "")")

        // A bloom removed from the description is a count difference.
        let fewer: Data = try Self.edited(data, frame: name) { description in
            var blooms: [Any] = try #require(description["blooms"] as? [Any])
            blooms.removeLast()
            description["blooms"] = blooms
        }
        let fewerResult: String? = try NocturneGardenGolden.compare(frame, pinned: fewer)
        #expect(fewerResult?.contains("blooms, pinned") == true, "\(fewerResult ?? "nil")")
    }

    /// A changed colour, shadow cell count, move count, budget or tier detail fails naming the frame.
    @Test func colourCountAndTierChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: NocturneGardenGolden.Frame = try Self.frame(name)

        let palette: Data = try Self.edited(data, frame: name) { description in
            var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
            var gold: [String: Any] = try #require(colours["gold"] as? [String: Any])
            let g: Int = try #require(gold["g"] as? Int)
            gold["g"] = g == 255 ? 254 : g + 1
            colours["gold"] = gold
            description["colours"] = colours
        }
        let paletteResult: String? = try NocturneGardenGolden.compare(frame, pinned: palette)
        #expect(paletteResult == "\(name): colour gold differs", "\(paletteResult ?? "nil")")

        let shadow: String? = try NocturneGardenGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "shadowCells", by: 1))
        #expect(shadow?.hasPrefix("\(name): ") == true, "\(shadow ?? "nil")")
        #expect(shadow?.contains("shadow cells, pinned") == true, "\(shadow ?? "nil")")

        let moves: String? = try NocturneGardenGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "moves", by: 1))
        #expect(moves?.hasPrefix("\(name): moves ") == true, "\(moves ?? "nil")")

        let budget: String? = try NocturneGardenGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "budget", by: -1))
        #expect(budget?.hasPrefix("\(name): budget ") == true, "\(budget ?? "nil")")

        let tierKeys: [String] = ["mistLayers", "stemDepth", "featherHundredths", "glowShells"]
        for key in tierKeys {
            let tier: String? = try NocturneGardenGolden.compare(
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
        let message: String? = try NocturneGardenGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")
    }
}
