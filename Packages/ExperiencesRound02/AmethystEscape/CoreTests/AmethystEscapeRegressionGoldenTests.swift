// AmethystEscapeRegressionGoldenTests — feature 368 (R02-G07-08) T-R02G0708-004 (FR-R02G0708-003, 004;
// SC-R02G0708-003; clarification Q3). The code-only visual baseline of Amethyst Escape: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 after the first min(smallest − 1, 3) witness actions, then the hero
// frame) in its fixed order with unique names; every frame describes the pearl, the exit arrow and every wedge top
// (shell by shell, sector ascending, open or blocked), the eight palette colours, the move count, the move bar and the
// tier's detail, with the pearl still inside; deterministic descriptions; every frame's recomputed description against
// the pinned file AmethystEscape/golden-frames.json; every pinned digest against the digest of its pinned description;
// and the failures the comparison must name, built from the pinned manifest in memory (the file is never written by
// them): a pearl centre, exit arrow or wedge top moved by two 1/8-pixel quanta fails naming the frame while one quantum
// passes, a move bar changed by two 1/1,024 quanta (one passes), a changed palette colour, a changed move count,
// changed tier detail, a missing frame, a renamed or unknown frame, a schema other than 1, an unreadable file and a
// hand-edited description that kept its old digest.
//
// The pinned file is written only when AMETHYST_ESCAPE_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     AMETHYST_ESCAPE_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter AmethystEscapeRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule).
@testable import AmethystEscapeCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath

/// The pinned golden file, found from this file (…/AmethystEscape/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

@Suite struct AmethystEscapeRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["AMETHYST_ESCAPE_WRITE_GOLDEN"] == "1" }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try AmethystEscapeGolden.manifest()
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
        let decoded: AmethystEscapeGolden.Description = try JSONDecoder().decode(
            AmethystEscapeGolden.Description.self, from: try JSONSerialization.data(withJSONObject: description))
        return StableHash.sha256Hex(Array(try AmethystEscapeGolden.encoder.encode(decoded)))
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

    /// `point` (a JSON position) moved by `dx`, `dy` quanta.
    static func movedPoint(_ point: Any?, dx: Int, dy: Int) throws -> [String: Any] {
        var position: [String: Any] = try #require(point as? [String: Any])
        let x: Int = try #require(position["x"] as? Int)
        let y: Int = try #require(position["y"] as? Int)
        position["x"] = x + dx
        position["y"] = y + dy
        return position
    }

    /// The manifest `data` with the top-level position `key` (`pearl` or `exit`) of `frame`'s description moved by
    /// `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, key: String, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            description[key] = try movedPoint(description[key], dx: dx, dy: dy)
        }
    }

    /// The index of the first wedge of `frame`'s pinned description that has a position.
    static func firstPlacedWedge(_ data: Data, frame: String) throws -> Int {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        let entry: [String: Any] = try #require(frames[frame] as? [String: Any])
        let description: [String: Any] = try #require(entry["description"] as? [String: Any])
        let wedges: [Any] = try #require(description["wedges"] as? [Any])
        for (index, item) in wedges.enumerated() {
            let wedge: [String: Any] = try #require(item as? [String: Any])
            if wedge["position"] is [String: Any] { return index }
        }
        Issue.record("\(frame) has no placed wedge")
        throw CancellationError()
    }

    /// The manifest `data` with the position of wedge `index` of `frame`'s description moved by `dx`, `dy` quanta.
    static func movedWedge(_ data: Data, frame: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
        try edited(data, frame: frame) { description in
            var wedges: [Any] = try #require(description["wedges"] as? [Any])
            var wedge: [String: Any] = try #require(wedges[index] as? [String: Any])
            wedge["position"] = try movedPoint(wedge["position"], dx: dx, dy: dy)
            wedges[index] = wedge
            description["wedges"] = wedges
        }
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> AmethystEscapeGolden.Frame {
        for frame in AmethystEscapeGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    @Test func theGoldenSetIsFixed() throws {
        let frames: [AmethystEscapeGolden.Frame] = AmethystEscapeGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(AmethystEscapeGolden.levels == levels)
        #expect(AmethystEscapeGolden.width == 1_152)
        #expect(AmethystEscapeGolden.height == 768)
        #expect(AmethystEscapeGolden.schema == 1)
        #expect(AmethystEscapeGolden.quantum == 8)
        #expect(AmethystEscapeGolden.lengthQuantum == 1_024)
        #expect(AmethystEscapeGolden.moves == 3)
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
            // The first min(smallest − 1, 3) witness actions, so the escape is never complete.
            let witness: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(level)
            #expect(witness.count >= 2, "level \(level) witness has \(witness.count) actions")
            let count: Int = max(0, min(witness.count - 1, 3))
            let expected: [AmethystEscapeAction] = Array(witness.prefix(count))
            #expect(!expected.isEmpty, "level \(level) has an empty witness prefix")
            for tier in 0..<3 {
                let frame: AmethystEscapeGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == AmethystEscapeGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                index += 1
            }
        }
        let hero: AmethystEscapeGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        #expect(hero.level == 1)
        #expect(hero.tier == 0)
        #expect(hero.time == 0)
        // The hero frame is the hero scenario's first turn.
        let inputActions: [AmethystEscapeAction] = AmethystEscapeExperienceCore.inputActions
        let firstInput: AmethystEscapeAction = try #require(inputActions.first)
        #expect(AmethystEscapeExperienceCore.heroEntries.count == 1)
        #expect(AmethystEscapeExperienceCore.heroEntries.first?.action
            == AmethystEscapeExperienceCore.scripted(firstInput))
        #expect(hero.actions == [firstInput])
        let heroSnapshot: AmethystEscapeSceneSnapshot = try AmethystEscapeGolden.snapshot(hero)
        let openingSnapshot: AmethystEscapeSceneSnapshot = try AmethystEscapeGolden.snapshot(
            AmethystEscapeGolden.Frame(name: "opening", level: 1, tier: 0, time: 0, actions: []))
        #expect(heroSnapshot != openingSnapshot)
    }

    @Test func everyFrameDescribesThePearlExitWedgesAndMoveBar() throws {
        for frame in AmethystEscapeGolden.frames {
            let snapshot: AmethystEscapeSceneSnapshot = try AmethystEscapeGolden.snapshot(frame)
            let description: AmethystEscapeGolden.Description = try AmethystEscapeGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(!snapshot.escaped, "\(frame.name) pearl has escaped")
            #expect(description.pearl != nil, "\(frame.name) pearl is off screen")
            #expect(description.exit != nil, "\(frame.name) exit arrow is off screen")
            // Every wedge top, shell by shell, own sector ascending, open unless blocked, on screen.
            #expect(description.wedges.count == snapshot.shells.count * snapshot.sectors, "\(frame.name) wedges")
            var index: Int = 0
            for (shell, entry) in snapshot.shells.enumerated() {
                for sector in 0..<snapshot.sectors {
                    if index < description.wedges.count {
                        let wedge: AmethystEscapeGolden.Wedge = description.wedges[index]
                        #expect(wedge.shell == shell && wedge.sector == sector,
                                "\(frame.name) wedge \(index) is \(wedge.shell).\(wedge.sector)")
                        #expect(wedge.open == !entry.blocked.contains(sector), "\(frame.name) wedge \(shell).\(sector)")
                        #expect(wedge.position != nil, "\(frame.name) wedge top \(shell).\(sector) is off screen")
                    }
                    index += 1
                }
            }
            // The move count and the move bar, quantized to 1/1,024.
            #expect(description.moves == snapshot.moves)
            #expect(description.moves == frame.actions.count, "\(frame.name) moves \(description.moves)")
            #expect(description.moves > 0, "\(frame.name) shows no move")
            let length: Double = AmethystEscapeSceneGeometry.moveBarLength(snapshot)
            #expect(description.moveBar == Int((length * 1_024).rounded()))
            #expect(description.moveBar > 0, "\(frame.name) move bar is empty")
            // The palette in 8-bit sRGB.
            let palette = AmethystEscapePalette.self
            #expect(description.backdrop == AmethystEscapeGolden.colour(palette.backdrop))
            #expect(description.amethyst == AmethystEscapeGolden.colour(palette.amethyst))
            #expect(description.highlight == AmethystEscapeGolden.colour(palette.highlight))
            #expect(description.platinum == AmethystEscapeGolden.colour(palette.platinum))
            #expect(description.blocked == AmethystEscapeGolden.colour(palette.blocked))
            #expect(description.pearlColour == AmethystEscapeGolden.colour(palette.pearl))
            #expect(description.exitColour == AmethystEscapeGolden.colour(palette.exit))
            #expect(description.amber == AmethystEscapeGolden.colour(palette.amber))
            #expect(description.amethyst == AmethystEscapeGolden.Colour(r: 0x8E, g: 0x4F, b: 0xD8))
            #expect(description.amber == AmethystEscapeGolden.Colour(r: 0xFF, g: 0xB0, b: 0x20))
            // The tier's detail.
            let tier: AmethystEscapeTier = AmethystEscapeTier.of(frame.tier)
            #expect(description.bevelSegments == tier.bevelSegments)
            #expect(description.highlightLayers == tier.highlightLayers)
            #expect(description.glowShells == tier.glowShells)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
        }
    }

    @Test func descriptionsAreDeterministic() throws {
        let frames: [AmethystEscapeGolden.Frame] = AmethystEscapeGolden.frames
        for frame in frames {
            let first: Data = try AmethystEscapeGolden.description(frame)
            let second: Data = try AmethystEscapeGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try AmethystEscapeGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try AmethystEscapeGolden.manifest()
        let again: Data = try AmethystEscapeGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try AmethystEscapeGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try AmethystEscapeGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not AmethystEscapeGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with AMETHYST_ESCAPE_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter AmethystEscapeRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        for frame in AmethystEscapeGolden.frames {
            let result: String? = try AmethystEscapeGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without AMETHYST_ESCAPE_WRITE_GOLDEN=1")
        }
    }

    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in AmethystEscapeGolden.frames {
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
        let first: AmethystEscapeGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try AmethystEscapeGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        let empty: String? = try AmethystEscapeGolden.compare(first, pinned: Data())
        #expect(empty == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try AmethystEscapeGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try AmethystEscapeGolden.compare(try Self.frame("level-041-tier-1"), pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try AmethystEscapeGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        // A renamed entry: the frame's own name is gone from the file.
        var renamedRoot: [String: Any] = try Self.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamed: String? = try AmethystEscapeGolden.compare(try Self.frame("level-061-tier-2"),
                                                                 pinned: try Self.bytes(renamedRoot))
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")

        // A description whose name differs from its frame (re-digested) is an identity difference.
        let identity: Data = try Self.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try AmethystEscapeGolden.compare(try Self.frame("level-081-tier-0"),
                                                                         pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")

        let unknown: AmethystEscapeGolden.Frame = AmethystEscapeGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try AmethystEscapeGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-021-tier-1"
        let frame: AmethystEscapeGolden.Frame = try Self.frame(name)

        let far: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "pearl", dx: 2))
        #expect(far?.hasPrefix("\(name): pearl centre at ") == true, "\(far ?? "nil")")

        let farY: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "pearl", dy: -2))
        #expect(farY?.hasPrefix("\(name): pearl centre at ") == true, "\(farY ?? "nil")")

        let near: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "pearl", dx: 1, dy: -1))
        #expect(near == nil, "\(near ?? "")")

        let exit: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "exit", dy: 2))
        #expect(exit?.hasPrefix("\(name): exit arrow at ") == true, "\(exit ?? "nil")")

        let nearExit: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, key: "exit", dx: -1))
        #expect(nearExit == nil, "\(nearExit ?? "")")

        let wedge: Int = try Self.firstPlacedWedge(data, frame: name)
        let wedgeResult: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.movedWedge(data, frame: name, index: wedge, dx: -2))
        #expect(wedgeResult?.hasPrefix("\(name): wedge top ") == true, "\(wedgeResult ?? "nil")")

        let nearWedge: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.movedWedge(data, frame: name, index: wedge, dx: 1, dy: 1))
        #expect(nearWedge == nil, "\(nearWedge ?? "")")

        // A wedge whose open flag flipped is a structural difference, not a position.
        let flipped: Data = try Self.edited(data, frame: name) { description in
            var wedges: [Any] = try #require(description["wedges"] as? [Any])
            var item: [String: Any] = try #require(wedges[0] as? [String: Any])
            let open: Bool = try #require(item["open"] as? Bool)
            item["open"] = !open
            wedges[0] = item
            description["wedges"] = wedges
        }
        let flippedResult: String? = try AmethystEscapeGolden.compare(frame, pinned: flipped)
        #expect(flippedResult?.hasPrefix("\(name): wedge 0.0 differs") == true, "\(flippedResult ?? "nil")")
    }

    @Test func paletteMovesMoveBarAndTierChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: AmethystEscapeGolden.Frame = try Self.frame(name)

        let palette: Data = try Self.edited(data, frame: name) { description in
            var amethyst: [String: Any] = try #require(description["amethyst"] as? [String: Any])
            let g: Int = try #require(amethyst["g"] as? Int)
            amethyst["g"] = g == 255 ? 254 : g + 1
            description["amethyst"] = amethyst
        }
        let paletteResult: String? = try AmethystEscapeGolden.compare(frame, pinned: palette)
        #expect(paletteResult == "\(name): palette colour differs", "\(paletteResult ?? "nil")")

        let moves: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "moves", by: 1))
        #expect(moves?.hasPrefix("\(name): moves ") == true, "\(moves ?? "nil")")

        let farBar: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "moveBar", by: 2))
        #expect(farBar?.hasPrefix("\(name): move bar ") == true, "\(farBar ?? "nil")")

        let nearBar: String? = try AmethystEscapeGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "moveBar", by: -1))
        #expect(nearBar == nil, "\(nearBar ?? "")")

        let tierKeys: [String] = ["bevelSegments", "highlightLayers", "glowShells"]
        for key in tierKeys {
            let tier: String? = try AmethystEscapeGolden.compare(
                frame, pinned: try Self.shifted(data, frame: name, key: key, by: 1))
            #expect(tier?.hasPrefix("\(name): tier detail differs") == true, "\(key): \(tier ?? "nil")")
        }
    }

    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try AmethystEscapeGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")
    }
}
