// HueCompassGolden — feature 338 (R02-G04-08) T-R02G0408-003 (FR-R02G0408-003, 004; clarification Q3; research R2, R3,
// R5; contracts/api.md). The code-only visual baseline of Hue Compass: a fixed golden set of 16 frames (certified levels
// 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0, each after its witness's probes and before the
// selection so the probe marks show, plus the hero frame: level 1 after the hero scenario's one turn, tier 0) and, for
// each, the description of what the frame must show at the frame-check size 1,152 × 768 with the authored camera — the
// projected needle tip, every band segment's colour sample point with its band colour, every probe mark centre, the
// selection mark and the target ring when present, the night, pearl, ember and sapphire colours and the tier's detail
// (facets, fog layers, glow shells). Positions are rounded to 1/8 pixel and colours to 8 bits, the whole serialized as
// JSON with sorted keys and hashed with SHA-256. Nothing is drawn here: the description is computed from the same CPU
// reference the renderer is checked against (feature 333), so it is a baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned one
// and everything else is equal (the system's trigonometry may differ in the last bit between macOS releases); otherwise
// it names the first differing value. A pinned digest must equal the digest of its pinned description, so a hand-edited
// entry cannot pass. Debug and automation builds only, like the scenarios; the Release symbol check forbids this type.
// Modelled on `WaveKnotKeeperGolden` (feature 328).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Hue Compass (see the file header).
public enum HueCompassGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`HueCompassTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's opening play before the frame.
        public let actions: [HueCompassAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [HueCompassAction]) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
        }
    }

    /// The frame-check width in pixels (the feature-333 frame-check size).
    public static let width = 1_152
    /// The frame-check height in pixels.
    public static let height = 768
    /// The schema of the pinned file.
    public static let schema = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum = 8
    /// The levels of the golden set, one per band.
    public static let levels: [Int] = [1, 21, 41, 61, 81]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame.
    ///
    /// - Throws: the kernel's refusal of a certified level.
    public static func frames() throws -> [Frame] {
        var list: [Frame] = []
        for level in levels {
            let probes: [HueCompassAction] = try witnessProbes(level: level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: 0,
                                  actions: probes))
            }
        }
        list.append(Frame(name: "hero", level: 1, tier: 0, time: 0,
                          actions: [.turn(HueCompassExperienceCore.inputTurns[0])]))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The certified witness actions of `level` without the final selection (its turns and probes).
    ///
    /// - Throws: the kernel's refusal of the level.
    static func witnessProbes(level: Int) throws -> [HueCompassAction] {
        let certified: HueCompassGenerated = try HueCompassExperienceCore.generated(number: level)
        let actions: [HueCompassAction] = HueCompassWitness.actions(for: certified.solution, level: certified.level)
        return actions.filter { action in
            if case .select = action { return false }
            return true
        }
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at its time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> HueCompassSceneSnapshot {
        let level = try HueCompassExperienceCore.level(number: frame.level)
        var play = try HueCompassExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return HueCompassSceneSnapshot(play: play, levelNumber: frame.level, time: frame.time)
    }

    /// A position in 1/``quantum`` pixel.
    struct Position: Codable, Equatable {
        let x: Int
        let y: Int
    }

    /// An 8-bit colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// A band segment's colour sample: its segment index, its pixel and its expected colour.
    struct Band: Codable, Equatable {
        let segment: Int
        let position: Position?
        let colour: Colour
    }

    /// A probe mark: its bearing and pixel.
    struct Mark: Codable, Equatable {
        let bearing: Int
        let position: Position?
    }

    /// The description of one frame (see the file header).
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let facets: Int
        let fogLayers: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let pearl: Colour
        let ember: Colour
        let sapphire: Colour
        let tip: Position?
        let bands: [Band]
        let probes: [Mark]
        let selection: Mark?
        let ring: Mark?
    }

    /// `c` in 8 bits per channel, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// `p` in 1/``quantum`` pixel; nil stays nil.
    static func position(_ p: Vec2?) -> Position? {
        guard let p else { return nil }
        return Position(x: Int((p.x * Double(quantum)).rounded()), y: Int((p.y * Double(quantum)).rounded()))
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot = try snapshot(frame)
        let tier = HueCompassTier.of(frame.tier)
        let geometry = HueCompassSceneGeometry.self
        let camera = geometry.camera(aspect: Double(width) / Double(height))
        func project(_ p: SIMD3<Double>) -> Position? {
            position(geometry.pixel(p, camera: camera, width: width, height: height))
        }
        var bands: [Band] = []
        for k in 0..<HueCompassWheel.bands {
            bands.append(Band(segment: k, position: project(geometry.bandSamplePoint(k)),
                              colour: colour(geometry.bandSegmentColour(k, in: snapshot))))
        }
        let probes: [Mark] = geometry.probeBearings(snapshot).map { b in
            Mark(bearing: b, position: project(geometry.probeMarkCentre(b)))
        }
        let selection: Mark? = snapshot.selection.map { s in
            let b: Int = ((s.bearing % HueCompassWheel.bearings) + HueCompassWheel.bearings) % HueCompassWheel.bearings
            return Mark(bearing: b, position: project(geometry.selectionMarkCentre(b)))
        }
        let ring: Mark? = snapshot.target.map { t in
            let b: Int = ((t % HueCompassWheel.bearings) + HueCompassWheel.bearings) % HueCompassWheel.bearings
            return Mark(bearing: b, position: project(geometry.targetRingCentre(b)))
        }
        return Description(name: frame.name, level: frame.level, tier: frame.tier, facets: tier.facets,
                           fogLayers: tier.fogLayers, glowShells: tier.glowShells, width: width, height: height,
                           quantum: quantum, night: colour(HueCompassPalette.night),
                           pearl: colour(HueCompassPalette.pearl), ember: colour(HueCompassPalette.ember),
                           sapphire: colour(HueCompassPalette.sapphire), tip: project(geometry.needleTip(snapshot)),
                           bands: bands, probes: probes, selection: selection, ring: ring)
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// The description of `frame` as JSON with sorted keys.
    ///
    /// - Throws: the kernel's refusal of the level or of an action; an encoding failure.
    public static func description(_ frame: Frame) throws -> Data {
        try encoder.encode(describe(frame))
    }

    /// The SHA-256 hex of ``description(_:)``.
    ///
    /// - Throws: as ``description(_:)``.
    public static func digest(_ frame: Frame) throws -> String {
        StableHash.sha256Hex(Array(try description(frame)))
    }

    /// One pinned frame: its description and digest.
    struct Entry: Codable, Equatable {
        let description: Description
        let digest: String
    }

    /// The pinned file.
    struct Manifest: Codable, Equatable {
        let schema: Int
        let frames: [String: Entry]
    }

    /// The pinned file's content for the current code: `{"schema": 1, "frames": {name: {"description", "digest"}}}`,
    /// JSON with sorted keys, one entry per golden frame.
    ///
    /// - Throws: as ``description(_:)``.
    public static func manifest() throws -> Data {
        var entries: [String: Entry] = [:]
        for frame in try frames() {
            let described = try describe(frame)
            entries[frame.name] = Entry(description: described,
                                        digest: StableHash.sha256Hex(Array(try encoder.encode(described))))
        }
        return try encoder.encode(Manifest(schema: schema, frames: entries))
    }

    /// Compares `frame`'s recomputed description with its entry in the pinned file `pinned`. The pinned digest must be
    /// the digest of the pinned description. Returns nil when the recomputed digest equals it, or when every position
    /// lies within one quantum of the pinned one and everything else is equal; otherwise the first difference in words,
    /// naming the frame.
    ///
    /// - Throws: as ``description(_:)``.
    public static func compare(_ frame: Frame, pinned: Data) throws -> String? {
        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: pinned) else {
            return "golden-frames.json is unreadable"
        }
        guard manifest.schema == schema else { return "golden-frames.json has schema \(manifest.schema), not \(schema)" }
        guard let entry = manifest.frames[frame.name] else { return "golden-frames.json has no frame \(frame.name)" }
        guard StableHash.sha256Hex(Array(try encoder.encode(entry.description))) == entry.digest else {
            return "golden-frames.json entry \(frame.name): the digest does not match its description"
        }
        let current = try describe(frame)
        if StableHash.sha256Hex(Array(try encoder.encode(current))) == entry.digest { return nil }
        return difference(current, entry.description)
    }

    /// The first difference between `a` (recomputed) and `b` (pinned) beyond one quantum of position, or nil.
    static func difference(_ a: Description, _ b: Description) -> String? {
        let frame = a.name
        if a.name != b.name || a.level != b.level || a.tier != b.tier {
            return "\(frame): identity differs (\(b.name) level \(b.level) tier \(b.tier) pinned)"
        }
        if a.facets != b.facets || a.fogLayers != b.fogLayers || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs (pinned \(b.facets) facets, \(b.fogLayers) fog layers, "
                + "\(b.glowShells) glow shells)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.night != b.night || a.pearl != b.pearl || a.ember != b.ember || a.sapphire != b.sapphire {
            return "\(frame): palette colour differs"
        }
        if !near(a.tip, b.tip) { return "\(frame): needle tip at \(text(a.tip)) eighths, pinned \(text(b.tip))" }
        if a.bands.count != b.bands.count { return "\(frame): band count differs" }
        for (m, n) in zip(a.bands, b.bands) {
            if m.segment != n.segment || m.colour != n.colour { return "\(frame): band segment \(m.segment) differs" }
            if !near(m.position, n.position) {
                return "\(frame): band segment \(m.segment) at \(text(m.position)) eighths, pinned \(text(n.position))"
            }
        }
        if let message = marks("probe mark", a.probes, b.probes, frame: frame) { return message }
        if let message = marks("selection mark", a.selection.map { [$0] } ?? [], b.selection.map { [$0] } ?? [],
                               frame: frame) {
            return message
        }
        return marks("target ring", a.ring.map { [$0] } ?? [], b.ring.map { [$0] } ?? [], frame: frame)
    }

    /// The first `kind` mark of `a` that differs from `b`'s in bearing or beyond one quantum of position, or a count
    /// difference, in words; nil when none.
    static func marks(_ kind: String, _ a: [Mark], _ b: [Mark], frame: String) -> String? {
        if a.count != b.count { return "\(frame): \(kind) count differs" }
        for (m, n) in zip(a, b) {
            if m.bearing != n.bearing { return "\(frame): \(kind) bearing \(m.bearing), pinned \(n.bearing)" }
            if !near(m.position, n.position) {
                return "\(frame): \(kind) \(m.bearing) at \(text(m.position)) eighths, pinned \(text(n.position))"
            }
        }
        return nil
    }

    /// Whether two positions lie within one quantum on each axis (both nil also counts).
    static func near(_ p: Position?, _ q: Position?) -> Bool {
        switch (p, q) {
        case (nil, nil): return true
        case let (p?, q?): return abs(p.x - q.x) <= 1 && abs(p.y - q.y) <= 1
        default: return false
        }
    }

    /// A position in words for messages.
    static func text(_ p: Position?) -> String {
        guard let p else { return "none" }
        return "(\(p.x), \(p.y))"
    }
}
#endif
