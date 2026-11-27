// MushroomWeatherGolden — feature 498 (R02-G20-08) T-R02G2008-003 (FR-R02G2008-003, 004; SC-R02G2008-003;
// clarification Q3; data-model.md "Frame description"; contracts/api.md). The code-only visual baseline of Mushroom
// Weather: a fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at
// presentation time 0, each after all of the witness's actions — the certified plan, the stored witness
// `docs/games/mushroom-weather/levels/NNN.witness.json` without its final run — but not the run, so actions are spent
// from the actions bars and the level is still open, with no preview, shown at the cycle half the cycles run
// (`cyclesRun / 2`, integer division, exactly as the feature-493 frame checks send `clock.show [cyclesRun / 2]`); plus
// the hero frame: the level the scenario manifest's hero scenario opens (seed `manifestSeed`) after that scenario's
// entries (the certified actions and the hero cycle shown, ``MushroomWeatherExperienceCore/heroCycle(_:)``), tier 0)
// and, for each, the description of what the frame must show at the frame-check size 1,152 × 768 with the authored
// camera: the floor centre, every cap centre (colony order), the moon centre, the first gauge track and the first
// actions bar; the counts of floor and blocked cells, mist squares, sites, pods, grown pods (grown by the shown cycle),
// vents, open vents, colonies, colonies in band at the shown cycle and lit and total actions bars; the moonlight; and
// the 21 palette colours (``MushroomWeatherPalette``, each `[r, g, b]`). Positions are rounded to 1/8 pixel (a point
// behind the eye, which does not project, is null) and colours to 8-bit sRGB, the whole serialized as JSON with sorted
// keys and hashed with SHA-256 (`StableHash`, so the hash needs no CryptoKit). Nothing is drawn here: the description is
// computed from the same snapshot and scene geometry the renderer draws (feature 493), so it is a baseline made by code,
// never a stored picture. The tiers share every position and count (only the lathes, droplets, fronds, motes and glow
// differ between tiers, and none of them is described), so the three tiers of a level differ only in their identity.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. `writeIfRequested` rewrites the
// file only when `MUSHROOM_WEATHER_WRITE_GOLDEN=1` is set. Debug and automation builds only, like the scenarios; the
// Release symbol check forbids this type. Modelled on `MicroscopicAuroraGolden` (feature 488).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Mushroom Weather (see the file header).
public enum MushroomWeatherGolden {
    /// One golden frame: a certified level, a host tier, a presentation time, the actions applied to the level's fresh
    /// play and the shown cycle.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`MushroomWeatherTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions (pods, vents and moonlight, never the run) applied to the level's fresh play.
        public let actions: [MushroomWeatherAction]
        /// The shown cycle (presentation state of the adapter), 0 … cycles run.
        public let cycle: Int

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [MushroomWeatherAction],
                    cycle: Int) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
            self.cycle = cycle
        }
    }

    /// The frame-check width in pixels.
    public static let width: Int = 1_152
    /// The frame-check height in pixels.
    public static let height: Int = 768
    /// The schema of the pinned file.
    public static let schema: Int = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum: Int = 8
    /// The levels of the golden set, one per band.
    public static let levels: [Int] = [1, 21, 41, 61, 81]
    /// The presentation time of every frame: 0 (positions follow the shown cycle, never the time).
    public static let time: Double = 0.0
    /// The environment switch that lets ``writeIfRequested(to:environment:)`` rewrite the pinned file.
    public static let writeSwitch: String = "MUSHROOM_WEATHER_WRITE_GOLDEN"
    /// The names of the described palette colours (`MushroomWeatherPalette.all`), in the order the comparison checks
    /// them.
    public static var colourNames: [String] {
        var names: [String] = []
        for entry in MushroomWeatherPalette.all { names.append(entry.name) }
        return names
    }

    /// The actions a level frame applies: the certified plan's actions (the witness's actions without the run; none
    /// for a level that cannot be generated).
    static func openActions(_ level: Int) -> [MushroomWeatherAction] {
        MushroomWeatherExperienceCore.certifiedActions(level)
    }

    /// The fresh play of certified level `level` after `actions`; nil when the level cannot be generated or the kernel
    /// refuses an action.
    static func play(_ level: Int, _ actions: [MushroomWeatherAction]) -> MushroomWeatherPlay? {
        guard let generated = try? MushroomWeatherExperienceCore.level(number: level),
              var play = try? MushroomWeatherExperienceCore.freshPlay(of: generated) else { return nil }
        for action in actions {
            guard (try? play.apply(action, expecting: play.fingerprint)) != nil else { return nil }
        }
        return play
    }

    /// The shown cycle of a level frame: half the cycles run by `level` after its actions, `cyclesRun / 2` (integer
    /// division, as the feature-493 frame checks); 0 when the level cannot be generated.
    static func shownCycle(_ level: Int) -> Int {
        guard let played = play(level, openActions(level)) else { return 0 }
        return played.report.cycles / 2
    }

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2 at the cycle half the cycles run, then
    /// the hero frame (the level the hero scenario opens, seed ``MushroomWeatherExperienceCore/manifestSeed``, after
    /// its entries: the certified actions and the hero cycle shown; tier 0).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [MushroomWeatherAction] = openActions(level)
            let cycle: Int = shownCycle(level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions, cycle: cycle))
            }
        }
        typealias Core = MushroomWeatherExperienceCore
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: openActions(heroLevel),
                          cycle: Core.heroCycle(heroLevel) ?? 0))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied and its cycle
    /// shown (clamped to 0 … cycles run), at the frame's time; no preview.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> MushroomWeatherSceneSnapshot {
        let level: MushroomWeatherLevel = try MushroomWeatherExperienceCore.level(number: frame.level)
        var play: MushroomWeatherPlay = try MushroomWeatherExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return MushroomWeatherSceneSnapshot(play: play, shownCycle: frame.cycle, levelNumber: frame.level,
                                            time: frame.time)
    }

    /// The counts of a description.
    struct Counts: Codable, Equatable {
        /// Floor cells.
        let floor: Int
        /// Blocked cells (logs and stones).
        let blocked: Int
        /// Mist squares (one per floor cell).
        let mist: Int
        /// Pod sites.
        let sites: Int
        /// Placed pods.
        let pods: Int
        /// Pods grown by the shown cycle.
        let grown: Int
        /// Vents.
        let vents: Int
        /// Open vents.
        let open: Int
        /// Colonies.
        let colonies: Int
        /// Colonies in band at the shown cycle.
        let inBand: Int
        /// Lit actions bars.
        let litActions: Int
        /// Actions bars in all (the budget).
        let actions: Int
    }

    /// The description of one frame (see the file header). A position is `[x, y]` in 1/``quantum`` pixel, or null; a
    /// colour is `[r, g, b]` in 8 bits.
    struct Description: Codable, Equatable {
        /// The frame's name.
        let name: String
        /// The level number.
        let level: Int
        /// The tier.
        let tier: Int
        /// The frame width in pixels.
        let width: Int
        /// The frame height in pixels.
        let height: Int
        /// Positions are in 1/`quantum` pixel.
        let quantum: Int
        /// The shown cycle.
        let cycle: Int
        /// The element counts.
        let counts: Counts
        /// The moonlight level, 0 … 3.
        let moonlight: Int
        /// The palette colours by name.
        let colours: [String: [Int]]
        /// The floor centre.
        let floor: [Int]?
        /// Every cap centre, colony order.
        let caps: [[Int]?]
        /// The moon centre.
        let moon: [Int]?
        /// The first colony's gauge track centre; null without colonies.
        let firstGaugeTrack: [Int]?
        /// The first actions bar; null without a budget.
        let firstActionsBar: [Int]?

        /// Encodes every field; a missing position is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(cycle, forKey: .cycle)
            try c.encode(counts, forKey: .counts)
            try c.encode(moonlight, forKey: .moonlight)
            try c.encode(colours, forKey: .colours)
            try c.encode(floor, forKey: .floor)
            try c.encode(caps, forKey: .caps)
            try c.encode(moon, forKey: .moon)
            try c.encode(firstGaugeTrack, forKey: .firstGaugeTrack)
            try c.encode(firstActionsBar, forKey: .firstActionsBar)
        }
    }

    /// `c` in 8 bits per channel, `[r, g, b]`, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> [Int] {
        [byte(c.x), byte(c.y), byte(c.z)]
    }

    /// One channel 0 … 1 as a byte.
    static func byte(_ v: Double) -> Int {
        Int((min(max(v, 0), 1) * 255).rounded())
    }

    /// The palette colour named `name` (one of ``colourNames``); black for an unknown name.
    static func paletteColour(_ name: String) -> SIMD3<Double> {
        for entry in MushroomWeatherPalette.all where entry.name == name { return entry.colour }
        return SIMD3(0, 0, 0)
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project (behind the eye or
    /// not finite).
    static func position(_ point: SIMD3<Double>, camera: MushroomWeatherCamera) -> [Int]? {
        guard let p = MushroomWeatherSceneGeometry.project(point, camera: camera) else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The camera of every frame: the authored camera at the frame-check aspect, ``width`` / ``height``.
    static var camera: MushroomWeatherCamera {
        MushroomWeatherSceneGeometry.camera(aspect: Double(width) / Double(height))
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        typealias G = MushroomWeatherSceneGeometry
        let snapshot: MushroomWeatherSceneSnapshot = try snapshot(frame)
        let camera: MushroomWeatherCamera = camera
        var caps: [[Int]?] = []
        for index in snapshot.colonies.indices { caps.append(position(G.capCentre(index, snapshot), camera: camera)) }
        var pods: Int = 0
        var grown: Int = 0
        for slot in snapshot.pods.indices where snapshot.pods[slot] != nil {
            pods += 1
            if snapshot.isGrown(slot) { grown += 1 }
        }
        var open: Int = 0
        for index in snapshot.vents.indices where G.ventOpen(index, snapshot) { open += 1 }
        var inBand: Int = 0
        for colony in snapshot.colonies where colony.inBand { inBand += 1 }
        let actions: Int = max(snapshot.budget, 0)
        let firstBar: [Int]? = actions > 0 ? position(G.actionsBar(0, snapshot), camera: camera) : nil
        let firstTrack: [Int]? = snapshot.colonies.isEmpty ? nil : position(G.gaugeTrackCentre(0), camera: camera)
        var colours: [String: [Int]] = [:]
        for entry in MushroomWeatherPalette.all { colours[entry.name] = colour(entry.colour) }
        let counts: Counts = Counts(floor: G.floorCells(snapshot).count, blocked: snapshot.blocked.count,
                                    mist: G.mistSquares(snapshot).count, sites: snapshot.sites.count, pods: pods,
                                    grown: grown, vents: snapshot.vents.count, open: open,
                                    colonies: snapshot.colonies.count, inBand: inBand,
                                    litActions: G.litActions(snapshot), actions: actions)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, cycle: snapshot.shownCycle, counts: counts,
                           moonlight: snapshot.moonlight, colours: colours,
                           floor: position(G.floorCentre(), camera: camera), caps: caps,
                           moon: position(G.moonCentre(), camera: camera), firstGaugeTrack: firstTrack,
                           firstActionsBar: firstBar)
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e: JSONEncoder = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// The SHA-256 hex of a description as the pinned file encodes it.
    static func hash(_ description: Description) throws -> String {
        StableHash.sha256Hex(Array(try encoder.encode(description)))
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
        /// The pinned description.
        let description: Description
        /// The SHA-256 hex of the pinned description.
        let digest: String
    }

    /// The pinned file.
    struct Manifest: Codable, Equatable {
        /// The schema, 1.
        let schema: Int
        /// The entries by frame name.
        let frames: [String: Entry]
    }

    /// The pinned file's content for the current code: `{"schema": 1, "frames": {name: {"description", "digest"}}}`,
    /// JSON with sorted keys, one entry per golden frame.
    ///
    /// - Throws: as ``description(_:)``.
    public static func manifest() throws -> Data {
        var entries: [String: Entry] = [:]
        for frame in frames {
            let described: Description = try describe(frame)
            entries[frame.name] = Entry(description: described, digest: try hash(described))
        }
        return try encoder.encode(Manifest(schema: schema, frames: entries))
    }

    /// Writes ``manifest()`` to `url` (atomically) only when `environment[writeSwitch]` is `"1"`
    /// (`MUSHROOM_WEATHER_WRITE_GOLDEN=1`); otherwise touches nothing.
    ///
    /// - Returns: whether the file was written.
    /// - Throws: as ``manifest()``; a write failure.
    @discardableResult
    public static func writeIfRequested(
        to url: URL, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Bool {
        guard environment[writeSwitch] == "1" else { return false }
        try manifest().write(to: url, options: [.atomic])
        return true
    }

    /// Compares `frame`'s recomputed description with its entry in the pinned file `pinned`. The pinned digest must be
    /// the digest of the pinned description. Returns nil when the recomputed digest equals it, or when every position
    /// lies within one quantum of the pinned one and every colour and count is equal; otherwise the first difference in
    /// words, naming the frame.
    ///
    /// - Throws: as ``description(_:)``.
    public static func compare(_ frame: Frame, pinned: Data) throws -> String? {
        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: pinned) else {
            return "golden-frames.json is unreadable"
        }
        guard manifest.schema == schema else {
            return "golden-frames.json has schema \(manifest.schema), not \(schema)"
        }
        guard let entry = manifest.frames[frame.name] else { return "golden-frames.json has no frame \(frame.name)" }
        guard try hash(entry.description) == entry.digest else {
            return "golden-frames.json entry \(frame.name): the digest does not match its description"
        }
        let current: Description = try describe(frame)
        if try hash(current) == entry.digest { return nil }
        return difference(current, entry.description)
    }

    /// The first difference between `a` (recomputed) and `b` (pinned) beyond one quantum of position, or nil.
    static func difference(_ a: Description, _ b: Description) -> String? {
        let frame: String = a.name
        if a.name != b.name || a.level != b.level || a.tier != b.tier {
            return "\(frame): identity differs (\(b.name) level \(b.level) tier \(b.tier) pinned)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.cycle != b.cycle { return "\(frame): cycle \(a.cycle), pinned cycle \(b.cycle)" }
        if a.counts != b.counts { return "\(frame): counts differ (pinned \(b.counts))" }
        if a.moonlight != b.moonlight { return "\(frame): moonlight \(a.moonlight), pinned \(b.moonlight)" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if !near(a.floor, b.floor) {
            return "\(frame): floor centre at \(text(a.floor)) eighths, pinned \(text(b.floor))"
        }
        if a.caps.count != b.caps.count { return "\(frame): \(a.caps.count) cap points, pinned \(b.caps.count)" }
        for index in a.caps.indices where !near(a.caps[index], b.caps[index]) {
            return "\(frame): cap \(index) at \(text(a.caps[index])) eighths, pinned " + text(b.caps[index])
        }
        if !near(a.moon, b.moon) { return "\(frame): moon centre at \(text(a.moon)) eighths, pinned \(text(b.moon))" }
        if !near(a.firstGaugeTrack, b.firstGaugeTrack) {
            return "\(frame): first gauge track at \(text(a.firstGaugeTrack)) eighths, pinned "
                + text(b.firstGaugeTrack)
        }
        if !near(a.firstActionsBar, b.firstActionsBar) {
            return "\(frame): first actions bar at \(text(a.firstActionsBar)) eighths, pinned "
                + text(b.firstActionsBar)
        }
        return nil
    }

    /// Whether two positions lie within one quantum on each axis (both nil also counts).
    static func near(_ p: [Int]?, _ q: [Int]?) -> Bool {
        guard let p, let q else { return p == nil && q == nil }
        guard p.count == 2, q.count == 2 else { return false }
        return abs(p[0] - q[0]) <= 1 && abs(p[1] - q[1]) <= 1
    }

    /// A position in words for messages.
    static func text(_ p: [Int]?) -> String {
        guard let p, p.count == 2 else { return "none" }
        return "(\(p[0]), \(p[1]))"
    }
}
#endif
