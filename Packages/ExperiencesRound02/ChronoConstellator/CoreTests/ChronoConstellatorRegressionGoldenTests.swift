// ChronoConstellatorRegressionGoldenTests — feature 358 (R02-G06-08) T-R02G0608-004 (FR-R02G0608-003, 004;
// SC-R02G0608-003; clarification Q3). The code-only visual baseline of Chrono Constellator: the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 after their witness phase changes and 6 ticks, then the hero frame)
// in its fixed order with unique names, every frame's recomputed description against the pinned file
// ChronoConstellator/golden-frames.json, every pinned digest against the digest of its pinned description, deterministic
// descriptions, and the failures the comparison must name, built from the pinned manifest in memory (the file is never
// written by them): a star centre moved by two 1/8-pixel quanta fails naming the frame while one quantum passes, a moved
// target centre and loop cell centre, a changed palette colour, a changed tick, a tick mark changed by two 1/1,024
// quanta (one passes), changed tier detail, a missing frame, a renamed or unknown frame, a schema other than 1, an
// unreadable file and a hand-edited description that kept its old digest.
//
// The pinned file is written only when CHRONO_CONSTELLATOR_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     CHRONO_CONSTELLATOR_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter ChronoConstellatorRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops, no nested closure literals (CI type-check rule).
@testable import ChronoConstellatorCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath

/// The pinned golden file, found from this file (…/ChronoConstellator/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

@Suite struct ChronoConstellatorRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["CHRONO_CONSTELLATOR_WRITE_GOLDEN"] == "1" }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try ChronoConstellatorGolden.manifest()
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
        let decoded: ChronoConstellatorGolden.Description = try JSONDecoder().decode(
            ChronoConstellatorGolden.Description.self, from: try JSONSerialization.data(withJSONObject: description))
        return StableHash.sha256Hex(Array(try ChronoConstellatorGolden.encoder.encode(decoded)))
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

    /// The index of the first item of the list `list` of `frame`'s pinned description that has a position.
    static func firstPlaced(_ data: Data, frame: String, list: String) throws -> Int {
        let root: [String: Any] = try tree(data)
        let frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        let entry: [String: Any] = try #require(frames[frame] as? [String: Any])
        let description: [String: Any] = try #require(entry["description"] as? [String: Any])
        let items: [Any] = try #require(description[list] as? [Any])
        for (index, item) in items.enumerated() {
            let point: [String: Any] = try #require(item as? [String: Any])
            if point["position"] is [String: Any] { return index }
        }
        Issue.record("\(frame) has no placed \(list)")
        throw CancellationError()
    }

    /// The manifest `data` with the position of item `index` of the list `list` of `frame`'s description moved by
    /// `dx`, `dy` quanta.
    static func moved(_ data: Data, frame: String, list: String, index: Int, dx: Int = 0, dy: Int = 0) throws -> Data {
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
    static func frame(_ name: String) throws -> ChronoConstellatorGolden.Frame {
        for frame in ChronoConstellatorGolden.frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    @Test func theGoldenSetIsFixed() throws {
        let frames: [ChronoConstellatorGolden.Frame] = ChronoConstellatorGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(ChronoConstellatorGolden.levels == levels)
        #expect(ChronoConstellatorGolden.width == 1_152)
        #expect(ChronoConstellatorGolden.height == 768)
        #expect(ChronoConstellatorGolden.schema == 1)
        #expect(ChronoConstellatorGolden.quantum == 8)
        #expect(ChronoConstellatorGolden.lengthQuantum == 1_024)
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
            // The witness phase changes in solver order, never its step, then the golden ticks.
            var expected: [ChronoConstellatorAction] = []
            for action in ChronoConstellatorExperienceCore.certifiedActions(level) {
                if case .step = action { continue }
                expected.append(action)
            }
            #expect(!expected.isEmpty, "level \(level) has no witness phase change")
            expected.append(.step(ChronoConstellatorGolden.ticks))
            for tier in 0..<3 {
                let frame: ChronoConstellatorGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == ChronoConstellatorGolden.name(level: level, tier: tier))
                #expect(frame.actions == expected, "\(frame.name) actions")
                index += 1
            }
        }
        let hero: ChronoConstellatorGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        #expect(hero.level == 1)
        #expect(hero.tier == 0)
        // The hero frame is the hero scenario's phase change followed by the golden ticks.
        let inputActions: [ChronoConstellatorAction] = ChronoConstellatorExperienceCore.inputActions
        let firstInput: ChronoConstellatorAction = try #require(inputActions.first)
        #expect(ChronoConstellatorExperienceCore.heroEntries.count == 1)
        #expect(ChronoConstellatorExperienceCore.heroEntries.first?.action
            == ChronoConstellatorExperienceCore.scripted(firstInput))
        #expect(hero.actions == [firstInput, ChronoConstellatorAction.step(ChronoConstellatorGolden.ticks)])
        let heroSnapshot: ChronoConstellatorSceneSnapshot = try ChronoConstellatorGolden.snapshot(hero)
        let openingSnapshot: ChronoConstellatorSceneSnapshot = try ChronoConstellatorGolden.snapshot(
            ChronoConstellatorGolden.Frame(name: "opening", level: 1, tier: 0, time: 0, actions: []))
        #expect(heroSnapshot != openingSnapshot)
    }

    @Test func everyFrameDescribesEveryStarTargetAndLoopCell() throws {
        for frame in ChronoConstellatorGolden.frames {
            let snapshot: ChronoConstellatorSceneSnapshot = try ChronoConstellatorGolden.snapshot(frame)
            let description: ChronoConstellatorGolden.Description = try ChronoConstellatorGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.level == frame.level)
            #expect(description.tier == frame.tier)
            #expect(description.stars.count == snapshot.stars.count)
            #expect(description.targets.count == snapshot.stars.count)
            var loopCells: Set<Int> = []
            for star in snapshot.stars { loopCells.formUnion(star.loop) }
            var cellIndices: [Int] = []
            for point in description.cells { cellIndices.append(point.index) }
            #expect(cellIndices == loopCells.sorted(), "\(frame.name) loop cells")
            for point in description.stars {
                #expect(point.position != nil, "\(frame.name) star \(point.index) is off screen")
            }
            for point in description.targets {
                #expect(point.position != nil, "\(frame.name) target \(point.index) is off screen")
            }
            #expect(description.tick == snapshot.tick)
            #expect(description.tick > 0 && description.tick <= ChronoConstellatorGolden.ticks,
                    "\(frame.name) tick \(description.tick)")
            #expect(description.tickMark >= 0)
            let tier: ChronoConstellatorTier = ChronoConstellatorTier.of(frame.tier)
            #expect(description.ribbonTicks == tier.ribbonTicks)
            #expect(description.segments == tier.segments)
            #expect(description.glowShells == tier.glowShells)
            #expect(description.width == 1_152 && description.height == 768 && description.quantum == 8)
        }
    }

    @Test func descriptionsAreDeterministic() throws {
        let frames: [ChronoConstellatorGolden.Frame] = ChronoConstellatorGolden.frames
        for frame in frames {
            let first: Data = try ChronoConstellatorGolden.description(frame)
            let second: Data = try ChronoConstellatorGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try ChronoConstellatorGolden.digest(frame)
            #expect(digest.count == 64)
            #expect(digest == StableHash.sha256Hex(Array(first)))
        }
        let manifest: Data = try ChronoConstellatorGolden.manifest()
        let again: Data = try ChronoConstellatorGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try ChronoConstellatorGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try ChronoConstellatorGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not ChronoConstellatorGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with CHRONO_CONSTELLATOR_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter ChronoConstellatorRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        for frame in ChronoConstellatorGolden.frames {
            let result: String? = try ChronoConstellatorGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without CHRONO_CONSTELLATOR_WRITE_GOLDEN=1")
        }
    }

    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        for frame in ChronoConstellatorGolden.frames {
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
        let first: ChronoConstellatorGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try ChronoConstellatorGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try ChronoConstellatorGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try ChronoConstellatorGolden.compare(try Self.frame("level-041-tier-1"),
                                                                     pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try ChronoConstellatorGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        // A renamed entry: the frame's own name is gone from the file.
        var renamedRoot: [String: Any] = try Self.tree(data)
        var renamedFrames: [String: Any] = try #require(renamedRoot["frames"] as? [String: Any])
        let entry: Any = try #require(renamedFrames["level-061-tier-2"])
        renamedFrames.removeValue(forKey: "level-061-tier-2")
        renamedFrames["level-061-tier-9"] = entry
        renamedRoot["frames"] = renamedFrames
        let renamed: String? = try ChronoConstellatorGolden.compare(try Self.frame("level-061-tier-2"),
                                                                     pinned: try Self.bytes(renamedRoot))
        #expect(renamed == "golden-frames.json has no frame level-061-tier-2")

        // A description whose name differs from its frame (re-digested) is an identity difference.
        let identity: Data = try Self.edited(data, frame: "level-081-tier-0") { description in
            description["name"] = "level-081-tier-1"
        }
        let identityResult: String? = try ChronoConstellatorGolden.compare(try Self.frame("level-081-tier-0"),
                                                                            pinned: identity)
        #expect(identityResult?.hasPrefix("level-081-tier-0: identity differs") == true, "\(identityResult ?? "nil")")

        let unknown: ChronoConstellatorGolden.Frame = ChronoConstellatorGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try ChronoConstellatorGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    @Test func positionChangesBeyondOneQuantumAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-021-tier-1"
        let frame: ChronoConstellatorGolden.Frame = try Self.frame(name)

        let star: Int = try Self.firstPlaced(data, frame: name, list: "stars")
        let far: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "stars", index: star, dx: 2))
        #expect(far?.hasPrefix("\(name): star centre \(star) at ") == true, "\(far ?? "nil")")

        let farY: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "stars", index: star, dy: -2))
        #expect(farY?.hasPrefix("\(name): star centre \(star) at ") == true, "\(farY ?? "nil")")

        let near: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "stars", index: star, dx: 1, dy: -1))
        #expect(near == nil, "\(near ?? "")")

        let target: Int = try Self.firstPlaced(data, frame: name, list: "targets")
        let targetResult: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "targets", index: target, dy: 2))
        #expect(targetResult?.hasPrefix("\(name): target centre \(target) at ") == true, "\(targetResult ?? "nil")")

        let cell: Int = try Self.firstPlaced(data, frame: name, list: "cells")
        let cellResult: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.moved(data, frame: name, list: "cells", index: cell, dx: -3))
        #expect(cellResult?.hasPrefix("\(name): loop cell centre ") == true, "\(cellResult ?? "nil")")
    }

    @Test func paletteTickAndTierChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-041-tier-2"
        let frame: ChronoConstellatorGolden.Frame = try Self.frame(name)

        let palette: Data = try Self.edited(data, frame: name) { description in
            var rose: [String: Any] = try #require(description["rose"] as? [String: Any])
            let g: Int = try #require(rose["g"] as? Int)
            rose["g"] = g == 255 ? 254 : g + 1
            description["rose"] = rose
        }
        let paletteResult: String? = try ChronoConstellatorGolden.compare(frame, pinned: palette)
        #expect(paletteResult == "\(name): palette colour differs", "\(paletteResult ?? "nil")")

        let tick: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "tick", by: 1))
        #expect(tick?.hasPrefix("\(name): tick ") == true && tick?.contains("tick mark") == false, "\(tick ?? "nil")")

        let farMark: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "tickMark", by: 2))
        #expect(farMark?.hasPrefix("\(name): tick mark ") == true, "\(farMark ?? "nil")")

        let nearMark: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "tickMark", by: -1))
        #expect(nearMark == nil, "\(nearMark ?? "")")

        let glow: String? = try ChronoConstellatorGolden.compare(
            frame, pinned: try Self.shifted(data, frame: name, key: "glowShells", by: 1))
        #expect(glow?.hasPrefix("\(name): tier detail differs") == true, "\(glow ?? "nil")")
    }

    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try ChronoConstellatorGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")
    }
}
