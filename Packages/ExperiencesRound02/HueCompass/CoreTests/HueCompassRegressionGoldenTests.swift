// HueCompassRegressionGoldenTests — feature 338 (R02-G04-08) T-R02G0408-004 (FR-R02G0408-003, 004; SC-R02G0408-003).
// The code-only visual baseline of Hue Compass (clarification Q3): the fixed golden set of 16 frames (levels 1, 21, 41,
// 61, 81 at tiers 0, 1, 2 after their witness probes, then the hero frame) in its fixed order with unique names, every
// frame's recomputed description against the pinned file HueCompass/golden-frames.json, every pinned digest against the
// digest of its pinned description, and the failures the comparison must name, built from the pinned manifest in memory
// (the file is never written by them): a needle tip moved by two 1/8-pixel quanta fails naming the frame while one
// quantum passes, a changed palette colour, a changed band colour, a missing frame, an unknown frame, a schema other than
// 1, an unreadable file and a hand-edited description that kept its old digest.
//
// The pinned file is written only when HUE_COMPASS_WRITE_GOLDEN=1 is set. Regenerate it after a reviewed visual change:
//     HUE_COMPASS_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
//         --filter HueCompassRegressionGoldenTests/everyFrameMatchesThePinnedFile
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import HueCompassCore
import Foundation
import Testing
import VisualCoreMath

/// The pinned golden file, found from this file (…/HueCompass/CoreTests/ → ../golden-frames.json).
private let goldenFile: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("golden-frames.json", isDirectory: false)

@Suite struct HueCompassRegressionGoldenTests {
    /// Whether this run may rewrite the pinned file.
    static var writing: Bool { ProcessInfo.processInfo.environment["HUE_COMPASS_WRITE_GOLDEN"] == "1" }

    /// The pinned file's bytes when it exists, else the current manifest.
    static func pinnedOrCurrent() throws -> Data {
        if FileManager.default.fileExists(atPath: goldenFile.path) { return try Data(contentsOf: goldenFile) }
        return try HueCompassGolden.manifest()
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
        let decoded: HueCompassGolden.Description = try JSONDecoder().decode(
            HueCompassGolden.Description.self, from: try JSONSerialization.data(withJSONObject: description))
        return StableHash.sha256Hex(Array(try HueCompassGolden.encoder.encode(decoded)))
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

    /// The golden frame named `name`.
    static func frame(_ name: String) throws -> HueCompassGolden.Frame {
        let frames: [HueCompassGolden.Frame] = try HueCompassGolden.frames()
        for frame in frames where frame.name == name { return frame }
        Issue.record("no golden frame \(name)")
        throw CancellationError()
    }

    /// The distinct bearings the witness probes of `frame` visit, in order.
    static func expectedProbeBearings(_ frame: HueCompassGolden.Frame) throws -> [Int] {
        let level: HueCompassLevel = try HueCompassExperienceCore.level(number: frame.level)
        let visited: [Int] = HueCompassWitness.probeBearings(frame.actions, start: level.start)
        var seen: Set<Int> = []
        var result: [Int] = []
        for bearing in visited where seen.insert(bearing).inserted { result.append(bearing) }
        return result
    }

    @Test func theGoldenSetIsFixed() throws {
        let frames: [HueCompassGolden.Frame] = try HueCompassGolden.frames()
        #expect(frames.count == 16)
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16)
        let levels: [Int] = [1, 21, 41, 61, 81]
        #expect(HueCompassGolden.levels == levels)
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
            for tier in 0..<3 {
                let frame: HueCompassGolden.Frame = frames[index]
                #expect(frame.level == level)
                #expect(frame.tier == tier)
                #expect(frame.time == 0)
                #expect(frame.name == HueCompassGolden.name(level: level, tier: tier))
                var probes: Int = 0
                for action in frame.actions {
                    if case .select = action { Issue.record("\(frame.name) applies a selection") }
                    if case .probe = action { probes += 1 }
                }
                #expect(probes > 0, "\(frame.name) applies no witness probe")
                index += 1
            }
        }
        let hero: HueCompassGolden.Frame = frames[15]
        #expect(hero.name == "hero")
        #expect(hero.level == 1)
        #expect(hero.tier == 0)
        #expect(hero.actions == [HueCompassAction.turn(HueCompassExperienceCore.inputTurns[0])])
        let heroSnapshot: HueCompassSceneSnapshot = try HueCompassGolden.snapshot(hero)
        let openingSnapshot: HueCompassSceneSnapshot = try HueCompassGolden.snapshot(
            HueCompassGolden.Frame(name: "opening", level: 1, tier: 0, time: 0, actions: []))
        #expect(heroSnapshot != openingSnapshot)
    }

    @Test func levelFramesCarryTheWitnessProbeMarksAndTheHeroNone() throws {
        let frames: [HueCompassGolden.Frame] = try HueCompassGolden.frames()
        for frame in frames {
            let description: HueCompassGolden.Description = try HueCompassGolden.describe(frame)
            #expect(description.name == frame.name)
            #expect(description.selection == nil, "\(frame.name) shows a selection mark")
            #expect(description.bands.count == HueCompassWheel.bands)
            #expect(description.tip != nil, "\(frame.name) needle tip is off screen")
            var bearings: [Int] = []
            for mark in description.probes {
                bearings.append(mark.bearing)
                #expect(mark.position != nil, "\(frame.name) probe mark \(mark.bearing) is off screen")
            }
            if frame.name == "hero" {
                #expect(bearings.isEmpty, "hero shows probe marks \(bearings)")
            } else {
                #expect(!bearings.isEmpty, "\(frame.name) shows no probe mark")
                #expect(bearings == (try Self.expectedProbeBearings(frame)), "\(frame.name) probe bearings")
            }
        }
    }

    @Test func descriptionsAreDeterministic() throws {
        let frames: [HueCompassGolden.Frame] = try HueCompassGolden.frames()
        for frame in frames {
            let first: Data = try HueCompassGolden.description(frame)
            let second: Data = try HueCompassGolden.description(frame)
            #expect(first == second, "\(frame.name) description differs between runs")
            let digest: String = try HueCompassGolden.digest(frame)
            #expect(digest.count == 64)
        }
        let manifest: Data = try HueCompassGolden.manifest()
        let again: Data = try HueCompassGolden.manifest()
        #expect(manifest == again)
        let levels: [Int] = [1, 21, 41, 61, 81]
        for level in levels {
            var digests: Set<String> = []
            for candidate in frames where candidate.level == level && candidate.name != "hero" {
                digests.insert(try HueCompassGolden.digest(candidate))
            }
            #expect(digests.count == 3, "level \(level) tiers share a digest")
        }
    }

    @Test func everyFrameMatchesThePinnedFile() throws {
        let before: Data? = FileManager.default.fileExists(atPath: goldenFile.path)
            ? try Data(contentsOf: goldenFile) : nil
        if Self.writing {
            let manifest: Data = try HueCompassGolden.manifest()
            try manifest.write(to: goldenFile, options: [.atomic])
            let written: Data = try Data(contentsOf: goldenFile)
            #expect(written == manifest, "the written file is not HueCompassGolden.manifest()")
        }
        guard FileManager.default.fileExists(atPath: goldenFile.path) else {
            Issue.record("""
                \(goldenFile.path) is missing; review the visuals and run with HUE_COMPASS_WRITE_GOLDEN=1 \
                swift test --package-path Packages/ExperiencesRound02 --filter HueCompassRegressionGoldenTests
                """)
            return
        }
        let pinned: Data = try Data(contentsOf: goldenFile)
        let frames: [HueCompassGolden.Frame] = try HueCompassGolden.frames()
        for frame in frames {
            let result: String? = try HueCompassGolden.compare(frame, pinned: pinned)
            #expect(result == nil, "\(result ?? "")")
        }
        let root: [String: Any] = try Self.tree(pinned)
        #expect(root["schema"] as? Int == 1)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        #expect(pinnedFrames.count == 16)
        if !Self.writing {
            // Without the switch the comparison never rewrites the file.
            let after: Data = try Data(contentsOf: goldenFile)
            #expect(after == before, "golden-frames.json changed without HUE_COMPASS_WRITE_GOLDEN=1")
        }
    }

    @Test func everyPinnedDigestIsTheDigestOfItsDescription() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let root: [String: Any] = try Self.tree(data)
        let pinnedFrames: [String: Any] = try #require(root["frames"] as? [String: Any])
        let frames: [HueCompassGolden.Frame] = try HueCompassGolden.frames()
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
        let first: HueCompassGolden.Frame = try Self.frame("level-001-tier-0")

        let garbage: Data = Data("not a manifest".utf8)
        let unreadable: String? = try HueCompassGolden.compare(first, pinned: garbage)
        #expect(unreadable == "golden-frames.json is unreadable")

        var root: [String: Any] = try Self.tree(data)
        root["schema"] = 2
        let schema: String? = try HueCompassGolden.compare(first, pinned: try Self.bytes(root))
        #expect(schema == "golden-frames.json has schema 2, not 1")

        var incomplete: [String: Any] = try Self.tree(data)
        var frames: [String: Any] = try #require(incomplete["frames"] as? [String: Any])
        frames.removeValue(forKey: "level-041-tier-1")
        incomplete["frames"] = frames
        let shortened: Data = try Self.bytes(incomplete)
        let missing: String? = try HueCompassGolden.compare(try Self.frame("level-041-tier-1"), pinned: shortened)
        #expect(missing == "golden-frames.json has no frame level-041-tier-1")
        let other: String? = try HueCompassGolden.compare(first, pinned: shortened)
        #expect(other == nil, "\(other ?? "")")

        let unknown: HueCompassGolden.Frame = HueCompassGolden.Frame(
            name: "level-002-tier-0", level: 2, tier: 0, time: 0, actions: [])
        let unknownResult: String? = try HueCompassGolden.compare(unknown, pinned: data)
        #expect(unknownResult == "golden-frames.json has no frame level-002-tier-0")
    }

    @Test func drawingChangesAreCaught() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let name: String = "level-021-tier-1"
        let frame: HueCompassGolden.Frame = try Self.frame(name)

        /// Moves the pinned needle tip right by `amount` quanta.
        func moved(_ amount: Int) throws -> Data {
            try Self.edited(data, frame: name) { description in
                var tip: [String: Any] = try #require(description["tip"] as? [String: Any])
                let x: Int = try #require(tip["x"] as? Int)
                tip["x"] = x + amount
                description["tip"] = tip
            }
        }

        let far: String? = try HueCompassGolden.compare(frame, pinned: try moved(2))
        #expect(far?.hasPrefix("\(name): needle tip at ") == true, "\(far ?? "nil")")

        let near: String? = try HueCompassGolden.compare(frame, pinned: try moved(1))
        #expect(near == nil, "\(near ?? "")")

        /// Moves the first probe mark down by two quanta.
        let probe: Data = try Self.edited(data, frame: name) { description in
            var probes: [Any] = try #require(description["probes"] as? [Any])
            var mark: [String: Any] = try #require(probes.first as? [String: Any])
            var position: [String: Any] = try #require(mark["position"] as? [String: Any])
            let y: Int = try #require(position["y"] as? Int)
            position["y"] = y + 2
            mark["position"] = position
            probes[0] = mark
            description["probes"] = probes
        }
        let probeResult: String? = try HueCompassGolden.compare(frame, pinned: probe)
        #expect(probeResult?.hasPrefix("\(name): probe mark ") == true, "\(probeResult ?? "nil")")

        let colour: Data = try Self.edited(data, frame: name) { description in
            var ember: [String: Any] = try #require(description["ember"] as? [String: Any])
            let r: Int = try #require(ember["r"] as? Int)
            ember["r"] = r == 0 ? 1 : r - 1
            description["ember"] = ember
        }
        let colourResult: String? = try HueCompassGolden.compare(frame, pinned: colour)
        #expect(colourResult == "\(name): palette colour differs", "\(colourResult ?? "nil")")

        let band: Data = try Self.edited(data, frame: name) { description in
            var bands: [Any] = try #require(description["bands"] as? [Any])
            var segment: [String: Any] = try #require(bands[5] as? [String: Any])
            var bandColour: [String: Any] = try #require(segment["colour"] as? [String: Any])
            let g: Int = try #require(bandColour["g"] as? Int)
            bandColour["g"] = g == 255 ? 254 : g + 1
            segment["colour"] = bandColour
            bands[5] = segment
            description["bands"] = bands
        }
        let bandResult: String? = try HueCompassGolden.compare(frame, pinned: band)
        #expect(bandResult == "\(name): band segment 5 differs", "\(bandResult ?? "nil")")

        let glow: Data = try Self.edited(data, frame: name) { description in
            let value: Int = try #require(description["glowShells"] as? Int)
            description["glowShells"] = value + 1
        }
        let glowResult: String? = try HueCompassGolden.compare(frame, pinned: glow)
        #expect(glowResult?.hasPrefix("\(name): tier detail differs") == true, "\(glowResult ?? "nil")")
    }

    @Test func aHandEditedDescriptionWithItsOldDigestIsRefused() throws {
        let data: Data = try Self.pinnedOrCurrent()
        let edited: Data = try Self.edited(data, frame: "hero", redigest: false) { description in
            description["glowShells"] = 9
        }
        let message: String? = try HueCompassGolden.compare(try Self.frame("hero"), pinned: edited)
        #expect(message == "golden-frames.json entry hero: the digest does not match its description",
                "\(message ?? "nil")")
    }
}
