// AuroraLoomRegressionGoldenTests — feature 308 (R02-G01-08) T-R02G0108-004 host part (FR-R02G0108-003, 004;
// SC-R02G0108-003; clarification Q3). The code-only visual baseline of Aurora Loom: the fixed golden set of 16 frames
// (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, then the hero frame), deterministic descriptions and manifest, every frame
// against the pinned file AuroraLoom/golden-frames.json, the named failures for a missing, unreadable or incomplete file,
// and the drawing changes the comparison must catch (a ribbon sample beyond one 1/8-pixel quantum, a marker colour, the
// tier detail, the night colour) while one quantum of drift passes, and an entry whose digest does not match its own
// description is refused.
//
// The pinned file is written only when AURORA_LOOM_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual change:
//     AURORA_LOOM_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomRegressionGoldenTests
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import AuroraLoomCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/AuroraLoom/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)


@Suite struct AuroraLoomRegressionGoldenTests {
    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try AuroraLoomGolden.manifest()
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

    /// The manifest `data` with the entry of `frame` replaced by `edit` applied to its description and the digest of the
    /// edited description (re-encoded as the Core encodes it), so the entry stays self-consistent and `compare` takes the
    /// tolerance path.
    static func edited(_ data: Data, frame: String,
                       _ edit: (inout [String: Any]) throws -> Void) throws -> Data {
        var root: [String: Any] = try tree(data)
        var frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var entry: [String: Any] = try #require(frames[frame] as? [String: Any])
        var description: [String: Any] = try #require(entry["description"] as? [String: Any])
        try edit(&description)
        entry["description"] = description
        let decoded: AuroraLoomGolden.Description = try JSONDecoder().decode(
            AuroraLoomGolden.Description.self, from: try JSONSerialization.data(withJSONObject: description))
        entry["digest"] = StableHash.sha256Hex(Array(try AuroraLoomGolden.encoder.encode(decoded)))
        frames[frame] = entry
        root["frames"] = frames
        return try bytes(root)
    }

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> AuroraLoomGolden.Frame {
        let frames: [AuroraLoomGolden.Frame] = AuroraLoomGolden.frames
        for frame in frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    @Test func theGoldenSetIsFixed() throws {
        let frames: [AuroraLoomGolden.Frame] = AuroraLoomGolden.frames
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        var index: Int = 0
        for level in levels {
            for tier in 0..<3 {
                let frame: AuroraLoomGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.moves.isEmpty)
                #expect(frame.name == AuroraLoomGolden.name(level: level, tier: tier))
                index += 1
            }
        }
        #expect(frames[0].name == "level-001-tier-0")
        #expect(frames[14].name == "level-081-tier-2")
        let hero: AuroraLoomGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        #expect(hero.level == 1)
        #expect(hero.tier == 0)
        #expect(hero.moves.count == 1)
        let heroSnapshot: AuroraLoomSceneSnapshot = try AuroraLoomGolden.snapshot(hero)
        let openingSnapshot: AuroraLoomSceneSnapshot = try AuroraLoomGolden.snapshot(frames[0])
        #expect(heroSnapshot != openingSnapshot)
    }

    @Test func descriptionsAreDeterministic() throws {
        let frames: [AuroraLoomGolden.Frame] = AuroraLoomGolden.frames
        for frame in frames {
            let first: Data = try AuroraLoomGolden.description(frame)
            let second: Data = try AuroraLoomGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try AuroraLoomGolden.digest(frame)
            #expect(digest.count == 64)
        }
        let manifest: Data = try AuroraLoomGolden.manifest()
        let again: Data = try AuroraLoomGolden.manifest()
        #expect(manifest == again)
    }

    @Test func everyFrameMatchesThePinnedFile() throws {
        if ProcessInfo.processInfo.environment["AURORA_LOOM_WRITE_GOLDEN"] == "1" {
            let manifest: Data = try AuroraLoomGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with AURORA_LOOM_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        let frames: [AuroraLoomGolden.Frame] = AuroraLoomGolden.frames
        for frame in frames {
            let result: String? = try AuroraLoomGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
    }

    @Test func aMissingUnreadableOrIncompleteManifestIsNamed() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let first: AuroraLoomGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try AuroraLoomGolden.compare(first, pinned: garbage)
        #expect(unreadable?.contains("golden-frames.json") == true)
        #expect(unreadable?.contains("unreadable") == true)

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try AuroraLoomGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema?.contains("golden-frames.json") == true)
        #expect(schema?.contains("schema 2") == true)

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try AuroraLoomGolden.compare(try Self.frame("level-041-tier-1"), pinned: shortened)
        #expect(missing?.contains("golden-frames.json") == true)
        #expect(missing?.contains("level-041-tier-1") == true)
        let other: String? = try AuroraLoomGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")
    }

    @Test func drawingChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-001-tier-0"
        let frame: AuroraLoomGolden.Frame = try Self.frame(name)

        /// Moves ribbon 0 sample 5 right by `amount` quanta.
        func moved(_ amount: Int) throws -> Data {
            try Self.edited(data, frame: name) { description in
                var ribbons: [Any] = try #require(description["ribbons"] as? [Any])
                var ribbon: [Any] = try #require(ribbons[0] as? [Any])
                var sample: [String: Any] = try #require(ribbon[5] as? [String: Any])
                let x: Int = try #require(sample["x"] as? Int)
                sample["x"] = x + amount
                ribbon[5] = sample
                ribbons[0] = ribbon
                description["ribbons"] = ribbons
            }
        }

        let far: String? = try AuroraLoomGolden.compare(frame, pinned: try moved(2))
        #expect(far?.contains(name) == true)
        #expect(far?.contains("ribbon 0 sample 5") == true, "\(far ?? "nil")")

        let near: String? = try AuroraLoomGolden.compare(frame, pinned: try moved(1))
        #expect(near == nil, "\(near ?? "")")

        let marker: Data = try Self.edited(data, frame: name) { description in
            var markers: [Any] = try #require(description["markers"] as? [Any])
            var first: [String: Any] = try #require(markers[0] as? [String: Any])
            var colour: [String: Any] = try #require(first["colour"] as? [String: Any])
            let r: Int = try #require(colour["r"] as? Int)
            colour["r"] = r == 0 ? 1 : r - 1
            first["colour"] = colour
            markers[0] = first
            description["markers"] = markers
        }
        let markerResult: String? = try AuroraLoomGolden.compare(frame, pinned: marker)
        #expect(markerResult?.contains(name) == true)
        #expect(markerResult?.contains("marker 0") == true, "\(markerResult ?? "nil")")

        let layers: Data = try Self.edited(data, frame: name) { description in
            let value: Int = try #require(description["layers"] as? Int)
            description["layers"] = value + 1
        }
        let layersResult: String? = try AuroraLoomGolden.compare(frame, pinned: layers)
        #expect(layersResult?.contains(name) == true)
        #expect(layersResult?.contains("tier detail") == true, "\(layersResult ?? "nil")")

        let night: Data = try Self.edited(data, frame: name) { description in
            var colour: [String: Any] = try #require(description["night"] as? [String: Any])
            let b: Int = try #require(colour["b"] as? Int)
            colour["b"] = b == 255 ? 254 : b + 1
            description["night"] = colour
        }
        let nightResult: String? = try AuroraLoomGolden.compare(frame, pinned: night)
        #expect(nightResult?.contains(name) == true)
        #expect(nightResult?.contains("night") == true, "\(nightResult ?? "nil")")

        let frames: [AuroraLoomGolden.Frame] = AuroraLoomGolden.frames
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.moves.isEmpty {
                digests.insert(try AuroraLoomGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    @Test func anEntryWhoseDigestDoesNotMatchItsDescriptionIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        var root: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(root["frames"] as? [String: Any])
        var entry: [String: Any] = try #require(frames["hero"] as? [String: Any])
        var description: [String: Any] = try #require(entry["description"] as? [String: Any])
        description["glowPasses"] = 9
        entry["description"] = description   // the digest is left as it was
        frames["hero"] = entry
        root["frames"] = frames
        let message: String? = try AuroraLoomGolden.compare(try Self.frame("hero"), pinned: try Self.bytes(root))
        #expect(message?.contains("hero") == true && message?.contains("does not match its description") == true)
    }
}
