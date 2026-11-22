// FacetedForgeRegressionGoldenTests — feature 378 (R02-G08-08) T-R02G0808-004 (FR-R02G0808-003, 004; SC-R02G0808-003;
// clarification Q3). The code-only visual baseline of Faceted Forge: the fixed golden set of 16 frames (levels 1, 21,
// 41, 61, 81 at tiers 0, 1, 2 at 1 s after the first min(smallest − 1, 2) certified cuts, then the hero frame) in its
// fixed order with unique names; every frame describes every piece centre in canonical order and the preview centre
// with the initial preview choice, the cuts spent and the budget, the nine palette colours and the tier's detail, with
// the level not won; deterministic descriptions; every frame's recomputed description against the pinned file
// FacetedForge/golden-frames.json; every pinned digest against the digest of its pinned description; and the failures
// the comparison must name, built from the pinned manifest in memory (the file is never written by them): a piece or
// preview centre moved by two 1/8-pixel quanta fails naming the frame while one quantum passes, a changed palette
// colour, a changed cut count or budget, changed tier detail, a missing frame, a renamed or unknown frame, a schema
// other than 1, an unreadable file and a hand-edited description that kept its old digest.
//
// The pinned file is written only when FACETED_FORGE_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     FACETED_FORGE_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter FacetedForgeRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule).
@testable import FacetedForgeCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/FacetedForge/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

@Suite struct FacetedForgeRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["FACETED_FORGE_WRITE_GOLDEN"] == "1" }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try FacetedForgeGolden.manifest()
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
        let decoded: FacetedForgeGolden.Description = try JSONDecoder().decode(
            FacetedForgeGolden.Description.self, from: data)
        return try FacetedForgeGolden.hash(decoded)
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

    /// The manifest `data` with the preview centre of `frame`'s description moved by `dx`, `dy` quanta.
    static func movedPreview(_ data: Data, frame: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description["preview"] = try movedPoint(description["preview"], dx: dx, dy: dy)
        }
    }

    /// The manifest `data` with piece `index`'s centre of `frame`'s description moved by `dx`, `dy` quanta.
    static func movedPiece(_ data: Data, frame: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var pieces: [Any] = try #require(description["pieces"] as? [Any])
            pieces[index] = try movedPoint(pieces[index], dx: dx, dy: dy)
            description["pieces"] = pieces
        }
    }

    /// The index of the first piece of `frame`'s pinned description that has a position.
    static func firstPlacedPiece(_ data: Data, frame: String) throws -> Int {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        let entry: [String: Any] = try #require(frames[frame] as? [String: Any])
        let description: [String: Any] = try #require(entry["description"] as? [String: Any])
        let pieces: [Any] = try #require(description["pieces"] as? [Any])
        for (index, item) in pieces.enumerated() where item is [Int] { return index }
        Issue.record("\(frame) has no placed piece")
        throw CancellationError()
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> FacetedForgeGolden.Frame {
        for frame in FacetedForgeGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    @Test func theGoldenSetIsFixed() throws {
        let frames: [FacetedForgeGolden.Frame] = FacetedForgeGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(FacetedForgeGolden.levels == levels)
        #expect(FacetedForgeGolden.width == 1_152)
        #expect(FacetedForgeGolden.height == 768)
        #expect(FacetedForgeGolden.schema == 1)
        #expect(FacetedForgeGolden.quantum == 8)
        #expect(FacetedForgeGolden.cuts == 2)
        #expect(FacetedForgeGolden.time == 1)
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
            // The first min(smallest − 1, 2) certified cuts, so the level is never won.
            let generated: FacetedForgeGenerated = try FacetedForgeExperienceCore.generated(number: level)
            let solution: [FacetedForgeAction] = generated.solution.actions
            #expect(solution.count == generated.solution.smallest, "level \(level) solution length")
            let count: Int = max(0, min(generated.solution.smallest - 1, 2))
            let expected: [FacetedForgeAction] = Array(solution.prefix(count))
            for tier in 0..<3 {
                let frame: FacetedForgeGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 1)
                #expect(frame.name == FacetedForgeGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                index += 1
            }
        }
        let hero: FacetedForgeGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        #expect(hero.level == 1)
        #expect(hero.tier == 0)
        #expect(hero.time == 1)
        // The hero frame is the hero scenario's first cut.
        let inputActions: [FacetedForgeAction] = FacetedForgeExperienceCore.inputActions
        let firstInput: FacetedForgeAction = try #require(inputActions.first)
        #expect(FacetedForgeExperienceCore.heroEntries.count == 1)
        #expect(FacetedForgeExperienceCore.heroEntries.first?.action
            == FacetedForgeExperienceCore.scripted(firstInput))
        #expect(hero.actions == [firstInput])
        let heroSnapshot: FacetedForgeSceneSnapshot = try FacetedForgeGolden.snapshot(hero)
        let openingSnapshot: FacetedForgeSceneSnapshot = try FacetedForgeGolden.snapshot(
            FacetedForgeGolden.Frame(name: "opening", level: 1, tier: 0, time: 1, actions: []))
        #expect(heroSnapshot != openingSnapshot)
        #expect(heroSnapshot.cuts == 1)
    }

    @Test func everyFrameDescribesPiecesPreviewCutsAndPalette() throws {
        for frame in FacetedForgeGolden.frames {
            let snapshot: FacetedForgeSceneSnapshot = try FacetedForgeGolden.snapshot(frame)
            let description: FacetedForgeGolden.Description = try FacetedForgeGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(!snapshot.won, "\(frame.name) is won")
            #expect(snapshot.stage == .playing, "\(frame.name) stage \(snapshot.stage)")
            // The initial preview choice of the frame's play.
            let level: FacetedForgeLevel = try FacetedForgeExperienceCore.level(number: frame.level)
            var play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: level)
            for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(snapshot.choice == FacetedForgePreviewChoice.initial(play), "\(frame.name) preview choice")
            // Every piece centre in canonical order, on screen; the preview centre on screen.
            #expect(description.pieces.count == snapshot.pieces.count, "\(frame.name) pieces")
            #expect(description.pieces.count == frame.actions.count + 1, "\(frame.name) piece count")
            for (index, piece) in description.pieces.enumerated() {
                #expect(piece != nil, "\(frame.name) piece \(index) is off screen")
            }
            #expect(!snapshot.preview.isEmpty, "\(frame.name) has no preview")
            #expect(description.preview != nil, "\(frame.name) preview is off screen")
            // The cut bars.
            #expect(description.cuts == snapshot.cuts)
            #expect(description.cuts == frame.actions.count, "\(frame.name) cuts \(description.cuts)")
            #expect(description.budget == snapshot.budget)
            #expect(description.budget > description.cuts, "\(frame.name) budget")
            // The palette in 8-bit sRGB.
            #expect(description.colours.count == 9)
            for name in FacetedForgeGolden.colourNames {
                let expected: FacetedForgeGolden.Colour = FacetedForgeGolden.colour(
                    FacetedForgeGolden.paletteColour(name))
                #expect(description.colours[name] == expected, "\(frame.name) colour \(name)")
            }
            #expect(description.colours["ruby"] == FacetedForgeGolden.Colour(r: 0xC8, g: 0x16, b: 0x3C))
            #expect(description.colours["unspent"] == FacetedForgeGolden.Colour(r: 0x3A, g: 0x45, b: 0x58))
            // The tier's detail and the size.
            let tier: FacetedForgeTier = FacetedForgeTier.of(frame.tier)
            #expect(description.bevelSegments == tier.bevelSegments)
            #expect(description.dispersionLayers == tier.dispersionLayers)
            #expect(description.glowShells == tier.glowShells)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
        }
    }

    @Test func descriptionsAreDeterministic() throws {
        let frames: [FacetedForgeGolden.Frame] = FacetedForgeGolden.frames
        for frame in frames {
            let first: Data = try FacetedForgeGolden.description(frame)
            let second: Data = try FacetedForgeGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try FacetedForgeGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try FacetedForgeGolden.manifest()
        let again: Data = try FacetedForgeGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try FacetedForgeGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try FacetedForgeGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not FacetedForgeGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with FACETED_FORGE_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter FacetedForgeRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        for frame in FacetedForgeGolden.frames {
            let result: String? = try FacetedForgeGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without FACETED_FORGE_WRITE_GOLDEN=1")
        }
    }

    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in FacetedForgeGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            #expect(pinnedDigest == (try Self.digest(of: description)), "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    @Test func aMissingUnreadableRenamedOrIncompleteManifestIsNamed() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let first: FacetedForgeGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try FacetedForgeGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try FacetedForgeGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try FacetedForgeGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try FacetedForgeGolden.compare(try Self.frame("level-041-tier-1"), pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try FacetedForgeGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        // A renamed entry: the frame's own name is gone from the file.
        var renamedRoot: [String: Any] = try Self.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamed: String? = try FacetedForgeGolden.compare(try Self.frame("level-061-tier-2"),
                                                               pinned: try Self.bytes(renamedRoot))
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")

        // A description whose name differs from its frame (re-digested) is an identity difference.
        let identity: Data = try Self.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try FacetedForgeGolden.compare(try Self.frame("level-081-tier-0"),
                                                                       pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")

        // An unknown frame (not in the golden set) is named.
        let unknown: FacetedForgeGolden.Frame = FacetedForgeGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 1, actions: [])
        let unknownResult: String? = try FacetedForgeGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-021-tier-1"
        let frame: FacetedForgeGolden.Frame = try Self.frame(name)

        let piece: Int = try Self.firstPlacedPiece(data, frame: name)
        let far: String? = try FacetedForgeGolden.compare(
            frame, pinned: try Self.movedPiece(data, frame: name, index: piece, dx: 2))
        #expect(far?.hasPrefix("\(name): piece \(piece) centre at ") == true, "\(far ?? "nil")")

        let farY: String? = try FacetedForgeGolden.compare(
            frame, pinned: try Self.movedPiece(data, frame: name, index: piece, dy: -2))
        #expect(farY?.hasPrefix("\(name): piece \(piece) centre at ") == true, "\(farY ?? "nil")")

        let near: String? = try FacetedForgeGolden.compare(
            frame, pinned: try Self.movedPiece(data, frame: name, index: piece, dx: 1, dy: -1))
        #expect(near == nil, "\(near ?? "")")

        let preview: String? = try FacetedForgeGolden.compare(
            frame, pinned: try Self.movedPreview(data, frame: name, dy: 2))
        #expect(preview?.hasPrefix("\(name): preview centre at ") == true, "\(preview ?? "nil")")

        let nearPreview: String? = try FacetedForgeGolden.compare(
            frame, pinned: try Self.movedPreview(data, frame: name, dx: -1))
        #expect(nearPreview == nil, "\(nearPreview ?? "")")

        // A piece removed from the description is a count difference.
        let fewer: Data = try Self.edited(data, frame: name) { description in
            var pieces: [Any] = try #require(description["pieces"] as? [Any])
            pieces.removeLast()
            description["pieces"] = pieces
        }
        let fewerResult: String? = try FacetedForgeGolden.compare(frame, pinned: fewer)
        #expect(fewerResult?.contains("pieces, pinned") == true, "\(fewerResult ?? "nil")")
    }

    @Test func colourCountAndTierChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: FacetedForgeGolden.Frame = try Self.frame(name)

        let palette: Data = try Self.edited(data, frame: name) { description in
            var colours: [String: Any] = try #require(description["colours"] as? [String: Any])
            var amber: [String: Any] = try #require(colours["amber"] as? [String: Any])
            let g: Int = try #require(amber["g"] as? Int)
            amber["g"] = g == 255 ? 254 : g + 1
            colours["amber"] = amber
            description["colours"] = colours
        }
        let paletteResult: String? = try FacetedForgeGolden.compare(frame, pinned: palette)
        #expect(paletteResult == "\(name): colour amber differs", "\(paletteResult ?? "nil")")

        let cuts: String? = try FacetedForgeGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "cuts", by: 1))
        #expect(cuts?.hasPrefix("\(name): cuts ") == true, "\(cuts ?? "nil")")

        let budget: String? = try FacetedForgeGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "budget", by: -1))
        #expect(budget?.hasPrefix("\(name): budget ") == true, "\(budget ?? "nil")")

        let tierKeys: [String] = ["bevelSegments", "dispersionLayers", "glowShells"]
        for key in tierKeys {
            let tier: String? = try FacetedForgeGolden.compare(
                frame, pinned: try Self.shifted(data, frame: name, key: key, by: 1))
            #expect(tier?.hasPrefix("\(name): tier detail differs") == true, "\(key): \(tier ?? "nil")")
        }
    }

    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try FacetedForgeGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")
    }
}
