// WaveKnotKeeperRegressionGoldenTests — feature 328 (R02-G03-08) T-R02G0308-004 (FR-R02G0308-003, 004;
// SC-R02G0308-003). The code-only visual baseline of Wave Knot Keeper (clarification Q3): the fixed golden set of 16
// frames (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, then the hero frame) in its fixed order with unique names, every
// frame's recomputed description against the pinned file WaveKnotKeeper/golden-frames.json, every pinned digest
// against the digest of its pinned description, and the failures the comparison must name, built from the current
// manifest in memory (the file is never written by them): a control point moved by two 1/8-pixel quanta fails naming
// the frame and the point while one quantum passes, a changed palette colour, a different tier detail, a missing frame,
// an unknown frame, a schema other than 1, an unreadable file and a hand-edited description that kept its old digest.
//
// The pinned file is written only when WAVE_KNOT_KEEPER_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual
// change:
//     WAVE_KNOT_KEEPER_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter WaveKnotKeeperRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import WaveKnotKeeperCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/WaveKnotKeeper/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

@Suite struct WaveKnotKeeperRegressionGoldenTests {
    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try WaveKnotKeeperGolden.manifest()
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
        let decoded: WaveKnotKeeperGolden.Description = try JSONDecoder().decode(
            WaveKnotKeeperGolden.Description.self, from: try JSONSerialization.data(withJSONObject: description))
        return StableHash.sha256Hex(Array(try WaveKnotKeeperGolden.encoder.encode(decoded)))
    }

    /// The manifest `data` with the entry of `frame` replaced by `edit` applied to its description and, when
    /// `redigest` is true, the digest of the edited description, so the entry stays self-consistent and `compare` takes
    /// the tolerance path; when false the old digest is kept (a hand edit).
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

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> WaveKnotKeeperGolden.Frame {
        let frames: [WaveKnotKeeperGolden.Frame] = WaveKnotKeeperGolden.frames
        for frame in frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    @Test func theGoldenSetIsFixed() throws {
        let frames: [WaveKnotKeeperGolden.Frame] = WaveKnotKeeperGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(WaveKnotKeeperGolden.levels == levels)
        var index: Int = 0
        for level in levels {
            for tier in 0..<3 {
                let frame: WaveKnotKeeperGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.moves.isEmpty)
                #expect(frame.name == WaveKnotKeeperGolden.name(level: level, tier: tier))
                index += 1
            }
        }
        #expect(frames[0].name == "level-001-tier-0")
        #expect(frames[14].name == "level-081-tier-2")
        let hero: WaveKnotKeeperGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        #expect(hero.level == 1)
        #expect(hero.tier == 0)
        #expect(hero.moves.count == 1)
        let heroSnapshot: WaveKnotKeeperSceneSnapshot = try WaveKnotKeeperGolden.snapshot(hero)
        let openingSnapshot: WaveKnotKeeperSceneSnapshot = try WaveKnotKeeperGolden.snapshot(frames[0])
        #expect(heroSnapshot != openingSnapshot)
    }

    @Test func descriptionsAreDeterministic() throws {
        let frames: [WaveKnotKeeperGolden.Frame] = WaveKnotKeeperGolden.frames
        for frame in frames {
            let first: Data = try WaveKnotKeeperGolden.description(frame)
            let second: Data = try WaveKnotKeeperGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try WaveKnotKeeperGolden.digest(frame)
            #expect(digest.count == 64)
        }
        let manifest: Data = try WaveKnotKeeperGolden.manifest()
        let again: Data = try WaveKnotKeeperGolden.manifest()
        #expect(manifest == again)
    }

    @Test func everyFrameMatchesThePinnedFile() throws {
        if ProcessInfo.processInfo.environment["WAVE_KNOT_KEEPER_WRITE_GOLDEN"] == "1" {
            let manifest: Data = try WaveKnotKeeperGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with WAVE_KNOT_KEEPER_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeperRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        let frames: [WaveKnotKeeperGolden.Frame] = WaveKnotKeeperGolden.frames
        for frame in frames {
            let result: String? = try WaveKnotKeeperGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
    }

    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        let frames: [WaveKnotKeeperGolden.Frame] = WaveKnotKeeperGolden.frames
        for frame in frames {
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
        let first: WaveKnotKeeperGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try WaveKnotKeeperGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try WaveKnotKeeperGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try WaveKnotKeeperGolden.compare(try Self.frame("level-041-tier-1"),
                                                                pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try WaveKnotKeeperGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        let unknown: WaveKnotKeeperGolden.Frame = WaveKnotKeeperGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, moves: [])
        let unknownResult: String? = try WaveKnotKeeperGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    @Test func drawingChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-001-tier-0"
        let frame: WaveKnotKeeperGolden.Frame = try Self.frame(name)

        // The first projected (non-nil) control point of the pinned description.
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        let entry: [String: Any] = try #require(pinnedFrames[name] as? [String: Any])
        let pinnedDescription: [String: Any] = try #require(entry["description"] as? [String: Any])
        let pinnedPoints: [Any] = try #require(pinnedDescription["points"] as? [Any])
        var pointIndex: Int = -1
        for i in 0..<pinnedPoints.count where pinnedPoints[i] is [String: Any] {
            pointIndex = i
            break
        }
        try #require(pointIndex >= 0, "no projected control point in \(name)")

        /// Moves control point `pointIndex` right by `amount` quanta.
        func moved(_ amount: Int) throws -> Data {
            try Self.edited(data, frame: name) { description in
                var points: [Any] = try #require(description["points"] as? [Any])
                var point: [String: Any] = try #require(points[pointIndex] as? [String: Any])
                let x: Int = try #require(point["x"] as? Int)
                point["x"] = x + amount
                points[pointIndex] = point
                description["points"] = points
            }
        }

        let far: String? = try WaveKnotKeeperGolden.compare(frame, pinned: try moved(2))
        #expect(far?.contains(name) == true)
        #expect(far?.contains("point \(pointIndex) ") == true, "\(far ?? "nil")")

        let near: String? = try WaveKnotKeeperGolden.compare(frame, pinned: try moved(1))
        #expect(near == nil, "\(near ?? "")")

        let colour: Data = try Self.edited(data, frame: name) { description in
            var ember: [String: Any] = try #require(description["ember"] as? [String: Any])
            let r: Int = try #require(ember["r"] as? Int)
            ember["r"] = r == 0 ? 1 : r - 1
            description["ember"] = ember
        }
        let colourResult: String? = try WaveKnotKeeperGolden.compare(frame, pinned: colour)
        #expect(colourResult == "\(name): palette colour differs", "\(colourResult ?? "nil")")

        let glow: Data = try Self.edited(data, frame: name) { description in
            let value: Int = try #require(description["glowShells"] as? Int)
            description["glowShells"] = value + 1
        }
        let glowResult: String? = try WaveKnotKeeperGolden.compare(frame, pinned: glow)
        #expect(glowResult?.contains(name) == true)
        #expect(glowResult?.contains("tier detail differs") == true, "\(glowResult ?? "nil")")

        let frames: [WaveKnotKeeperGolden.Frame] = WaveKnotKeeperGolden.frames
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.moves.isEmpty {
                digests.insert(try WaveKnotKeeperGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try WaveKnotKeeperGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")
    }
}
