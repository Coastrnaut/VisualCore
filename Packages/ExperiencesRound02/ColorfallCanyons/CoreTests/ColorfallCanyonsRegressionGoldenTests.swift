// ColorfallCanyonsRegressionGoldenTests — feature 348 (R02-G05-08) T-R02G0508-004 (FR-R02G0508-003, 004;
// SC-R02G0508-003). The code-only visual baseline of Colorfall Canyons (clarification Q3): the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 after their witness edits and 12 ticks, then the hero frame) in its
// fixed order with unique names, every frame's recomputed description against the pinned file
// ColorfallCanyons/golden-frames.json, every pinned digest against the digest of its pinned description, and the failures
// the comparison must name, built from the pinned manifest in memory (the file is never written by them): a cell top
// moved by two 1/8-pixel quanta fails naming the frame while one quantum passes, a moved emitter top, basin centre and
// sheet top, a changed palette colour, a changed fluid colour, a missing frame, an unknown frame, a schema other than 1,
// an unreadable file and a hand-edited description that kept its old digest.
//
// The pinned file is written only when COLORFALL_CANYONS_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     COLORFALL_CANYONS_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter ColorfallCanyonsRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import ColorfallCanyonsCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath

/// The pinned golden file, found from this file (…/ColorfallCanyons/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

@Suite struct ColorfallCanyonsRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["COLORFALL_CANYONS_WRITE_GOLDEN"] == "1" }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try ColorfallCanyonsGolden.manifest()
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
        let decoded: ColorfallCanyonsGolden.Description = try JSONDecoder().decode(
            ColorfallCanyonsGolden.Description.self, from: try JSONSerialization.data(withJSONObject: description))
        return StableHash.sha256Hex(Array(try ColorfallCanyonsGolden.encoder.encode(decoded)))
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

    /// The manifest `data` with the position of item `index` of the list `list` of `frame`'s description moved by
    /// `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, list: String, index: Int = 0, dx: Int = 0, dy: Int = 0) throws
        -> Data {
        try edited(data, frame: frame) { description in
            var items: [Any] = try #require(description[list] as? [Any])
            var item: [String: Any] = try #require(items[index] as? [String: Any])
            var position: [String: Any] = try #require(item["position"] as? [String: Any])
            let x: Int = try #require(position["x"] as? Int)
            let y: Int = try #require(position["y"] as? Int)
            position["x"] = x + dx
            position["y"] = y + dy
            item["position"] = position
            items[index] = item
            description[list] = items
        }
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> ColorfallCanyonsGolden.Frame {
        for frame in ColorfallCanyonsGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    @Test func theGoldenSetIsFixed() throws {
        let frames: [ColorfallCanyonsGolden.Frame] = ColorfallCanyonsGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(ColorfallCanyonsGolden.levels == levels)
        #expect(ColorfallCanyonsGolden.width == 1_152)
        #expect(ColorfallCanyonsGolden.height == 768)
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
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: level)
            var expected: [ColorfallCanyonsAction] = []
            for edit in generated.solution.edits { expected.append(edit.action) }
            expected.append(.step(12))
            #expect(!generated.solution.edits.isEmpty, "level \(level) has no witness edit")
            for tier in 0..<3 {
                let frame: ColorfallCanyonsGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == ColorfallCanyonsGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                index += 1
            }
        }
        let hero: ColorfallCanyonsGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        #expect(hero.level == 1)
        #expect(hero.tier == 0)
        // The hero frame is the hero scenario's final state: its one entry is the same time step.
        let heroEntries: [ScenarioStep] = ColorfallCanyonsExperienceCore.heroEntries
        #expect(heroEntries.count == 1)
        let heroTicks: Int = ColorfallCanyonsExperienceCore.inputSteps[0]
        #expect(heroEntries.first?.action == ScriptedAction("time.step", [Double(heroTicks)]))
        #expect(hero.actions == [ColorfallCanyonsAction.step(heroTicks)])
        let heroSnapshot: ColorfallCanyonsSceneSnapshot = try ColorfallCanyonsGolden.snapshot(hero)
        let openingSnapshot: ColorfallCanyonsSceneSnapshot = try ColorfallCanyonsGolden.snapshot(
            ColorfallCanyonsGolden.Frame(name: "opening", level: 1, tier: 0, time: 0, actions: []))
        #expect(heroSnapshot != openingSnapshot)
    }

    @Test func everyFrameDescribesTheWholeCanyonWithFluidShowing() throws {
        for frame in ColorfallCanyonsGolden.frames {
            let snapshot: ColorfallCanyonsSceneSnapshot = try ColorfallCanyonsGolden.snapshot(frame)
            let description: ColorfallCanyonsGolden.Description = try ColorfallCanyonsGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.cells.count == snapshot.cellCount)
            #expect(description.emitters.count == snapshot.springs.count)
            #expect(description.basins.count == snapshot.basins.count)
            #expect(!description.sheets.isEmpty, "\(frame.name) shows no fluid")
            var wet: Int = 0
            for cell in 0..<snapshot.cellCount where snapshot.volume(cell) > 0 { wet += 1 }
            #expect(description.sheets.count == wet)
            for point in description.cells {
                #expect(point.position != nil, "\(frame.name) cell \(point.index) is behind the camera")
            }
            for point in description.emitters {
                #expect(point.position != nil, "\(frame.name) emitter \(point.index) is behind the camera")
            }
            for sheet in description.sheets {
                let mix: SIMD3<Double> = ColorfallCanyonsPalette.fluid(snapshot.masses[sheet.cell])
                #expect(sheet.colour == ColorfallCanyonsGolden.colour(mix), "\(frame.name) sheet \(sheet.cell)")
            }
            let expectedTick: Int = frame.name == "hero" ? ColorfallCanyonsExperienceCore.inputSteps[0] : 12
            #expect(description.tick <= expectedTick && description.tick > 0, "\(frame.name) tick \(description.tick)")
            let tier: ColorfallCanyonsTier = ColorfallCanyonsTier.of(frame.tier)
            #expect(description.subdivision == tier.subdivision)
            #expect(description.flowBands == tier.flowBands)
            #expect(description.glowShells == tier.glowShells)
        }
    }

    @Test func descriptionsAreDeterministic() throws {
        let frames: [ColorfallCanyonsGolden.Frame] = ColorfallCanyonsGolden.frames
        for frame in frames {
            let first: Data = try ColorfallCanyonsGolden.description(frame)
            let second: Data = try ColorfallCanyonsGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try ColorfallCanyonsGolden.digest(frame)
            #expect(digest.count == 64)
        }
        let manifest: Data = try ColorfallCanyonsGolden.manifest()
        let again: Data = try ColorfallCanyonsGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try ColorfallCanyonsGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try ColorfallCanyonsGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not ColorfallCanyonsGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with COLORFALL_CANYONS_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter ColorfallCanyonsRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        for frame in ColorfallCanyonsGolden.frames {
            let result: String? = try ColorfallCanyonsGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without COLORFALL_CANYONS_WRITE_GOLDEN=1")
        }
    }

    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in ColorfallCanyonsGolden.frames {
            let entry: [String: Any] = try #require(pinnedFrames[frame.name] as? [String: Any])
            let description: [String: Any] = try #require(entry["description"] as? [String: Any])
            let pinnedDigest: String = try #require(entry["digest"] as? String)
            #expect(pinnedDigest == (try Self.digest(of: description)), "\(frame.name) digest")
            #expect(pinnedDigest.count == 64)
            #expect(description["name"] as? String == frame.name)
        }
    }

    @Test func aMissingUnreadableOrIncompleteManifestIsNamed() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let first: ColorfallCanyonsGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try ColorfallCanyonsGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try ColorfallCanyonsGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try ColorfallCanyonsGolden.compare(try Self.frame("level-041-tier-1"), pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try ColorfallCanyonsGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        let unknown: ColorfallCanyonsGolden.Frame = ColorfallCanyonsGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try ColorfallCanyonsGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    @Test func drawingChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-021-tier-1"
        let frame: ColorfallCanyonsGolden.Frame = try Self.frame(name)

        let far: String? = try ColorfallCanyonsGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "cells", index: 3, dx: 2))
        #expect(far?.hasPrefix("\(name): cell top 3 at ") == true, "\(far ?? "nil")")

        let near: String? = try ColorfallCanyonsGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "cells", index: 3, dx: 1, dy: -1))
        #expect(near == nil, "\(near ?? "")")

        let emitter: String? = try ColorfallCanyonsGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "emitters", dy: 2))
        #expect(emitter?.hasPrefix("\(name): emitter top 0 at ") == true, "\(emitter ?? "nil")")

        let basin: String? = try ColorfallCanyonsGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "basins", dx: -2))
        #expect(basin?.hasPrefix("\(name): basin centre 0 at ") == true, "\(basin ?? "nil")")

        let sheet: String? = try ColorfallCanyonsGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "sheets", dy: -3))
        #expect(sheet?.hasPrefix("\(name): sheet top ") == true, "\(sheet ?? "nil")")

        let palette: Data = try Self.edited(data, frame: name) { description in
            var sandstone: [String: Any] = try #require(description["sandstone"] as? [String: Any])
            let r: Int = try #require(sandstone["r"] as? Int)
            sandstone["r"] = r == 0 ? 1 : r - 1
            description["sandstone"] = sandstone
        }
        let paletteResult: String? = try ColorfallCanyonsGolden.compare(frame, pinned: palette)
        #expect(paletteResult == "\(name): palette colour differs", "\(paletteResult ?? "nil")")

        var wetCell: Int = -1
        let fluid: Data = try Self.edited(data, frame: name) { description in
            var sheets: [Any] = try #require(description["sheets"] as? [Any])
            var first: [String: Any] = try #require(sheets.first as? [String: Any])
            wetCell = try #require(first["cell"] as? Int)
            var colour: [String: Any] = try #require(first["colour"] as? [String: Any])
            let g: Int = try #require(colour["g"] as? Int)
            colour["g"] = g == 255 ? 254 : g + 1
            first["colour"] = colour
            sheets[0] = first
            description["sheets"] = sheets
        }
        let fluidResult: String? = try ColorfallCanyonsGolden.compare(frame, pinned: fluid)
        #expect(fluidResult == "\(name): fluid colour of cell \(wetCell) differs", "\(fluidResult ?? "nil")")

        let glow: Data = try Self.edited(data, frame: name) { description in
            let value: Int = try #require(description["glowShells"] as? Int)
            description["glowShells"] = value + 1
        }
        let glowResult: String? = try ColorfallCanyonsGolden.compare(frame, pinned: glow)
        #expect(glowResult?.hasPrefix("\(name): tier detail differs") == true, "\(glowResult ?? "nil")")
    }

    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try ColorfallCanyonsGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")
    }
}
