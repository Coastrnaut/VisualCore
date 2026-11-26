// MicroscopicAuroraGolden — feature 488 (R02-G19-08) T-R02G1908-003 (FR-R02G1908-003, 004; SC-R02G1908-003;
// clarification Q3; research R2, R3, R5, R6; data-model.md "Frame description"; contracts/api.md). The code-only
// visual baseline of Microscopic Aurora: a fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host
// tiers 0, 1 and 2 at presentation time 0, each after all of the witness's placements — the certified plan, the stored
// witness `docs/games/microscopic-aurora/levels/NNN.witness.json` without its final play — but not the play, so actions
// are spent from the actions bars and the level is still open, with no preview and no freeze, shown at the tick half
// the ticks swum (`ticksSwum / 2`, integer division, exactly as the feature-483 frame checks send
// `clock.show [ticksSwum / 2]`); plus the hero frame: the level the scenario manifest's hero scenario opens (seed
// `manifestSeed`) after that scenario's entries (the certified placements and the hero tick shown,
// ``MicroscopicAuroraExperienceCore/heroTick(_:)``), tier 0) and, for each, the description of what the frame must
// show at the frame-check size 1,152 × 768 with the authored camera: the dish centre, every swimmer at the shown tick
// (index order), every placed well (slot order, empty slots skipped), every site (index order) and the first actions
// bar; the counts of stencil cells, lit stencil cells, stray cells, sites, placed wells, swimmers, ribbon points (the
// sum over the swimmers of the tier's ribbon points, ``MicroscopicAuroraSceneGeometry/ribbon(_:_:tier:)`` — the one
// count that differs between tiers), gauges (the coverage and coherence tracks), met gauges and lit and total actions
// bars; and the 18 palette colours (each the palette constant of the same name). Positions are rounded to 1/8 pixel
// (a point behind the eye, which does not project, is null) and colours to 8-bit sRGB, the whole serialized as JSON
// with sorted keys and hashed with SHA-256 (`StableHash`, so the hash needs no CryptoKit). Nothing is drawn here: the
// description is computed from the same snapshot and scene geometry the renderer draws (feature 483), so it is a
// baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. `writeIfRequested` rewrites the
// file only when `MICROSCOPIC_AURORA_WRITE_GOLDEN=1` is set. Debug and automation builds only, like the scenarios; the
// Release symbol check forbids this type. Modelled on `ApsidesWorkshopGolden` (feature 478).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Microscopic Aurora (see the file header).
public enum MicroscopicAuroraGolden {
    /// One golden frame: a certified level, a host tier, a presentation time, the placements applied to the level's
    /// fresh play and the shown tick.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`MicroscopicAuroraTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions (placements, never the play) applied to the level's fresh play before the frame.
        public let actions: [MicroscopicAuroraAction]
        /// The shown tick (presentation state of the adapter), 0 … ticks swum.
        public let tick: Int

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [MicroscopicAuroraAction],
                    tick: Int) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
            self.tick = tick
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
    /// The presentation time of every frame: 0 (nothing in the dish moves by time; positions follow the shown tick).
    public static let time: Double = 0.0
    /// The number of gauges drawn: the coverage track and the coherence track.
    public static let gaugeCount: Int = 2
    /// The environment switch that lets ``writeIfRequested(to:environment:)`` rewrite the pinned file.
    public static let writeSwitch: String = "MICROSCOPIC_AURORA_WRITE_GOLDEN"
    /// The names of the described palette colours (`MicroscopicAuroraPalette`), in the order the comparison checks
    /// them.
    public static let colourNames: [String] = [
        "abyss", "abyssTop", "field", "frond", "rim", "stencil", "lit", "stray", "site", "well", "ribbon", "swimmer",
        "met", "unmet", "actionsLit", "actionsUnlit", "broken", "glow",
    ]

    /// The placements a level frame applies: the certified plan's placements (the witness's actions without the play;
    /// none for a level that cannot be generated).
    static func openPlacements(_ level: Int) -> [MicroscopicAuroraAction] {
        MicroscopicAuroraExperienceCore.certifiedActions(level)
    }

    /// The fresh play of certified level `level` after `actions`; nil when the level cannot be generated or the kernel
    /// refuses an action.
    static func play(_ level: Int, _ actions: [MicroscopicAuroraAction]) -> MicroscopicAuroraPlay? {
        guard let generated = try? MicroscopicAuroraExperienceCore.level(number: level),
              var play = try? MicroscopicAuroraExperienceCore.freshPlay(of: generated) else { return nil }
        for action in actions {
            guard (try? play.apply(action, expecting: play.fingerprint)) != nil else { return nil }
        }
        return play
    }

    /// The shown tick of a level frame: half the ticks swum by `level` after its placements, `ticksSwum / 2` (integer
    /// division, as the feature-483 frame checks); 0 when the level cannot be generated.
    static func shownTick(_ level: Int) -> Int {
        guard let played = play(level, openPlacements(level)) else { return 0 }
        return played.report.ticks / 2
    }

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2 at the tick half the ticks swum, then
    /// the hero frame (the level the hero scenario opens, seed ``MicroscopicAuroraExperienceCore/manifestSeed``, after
    /// its entries: the certified placements and the hero tick shown; tier 0).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [MicroscopicAuroraAction] = openPlacements(level)
            let tick: Int = shownTick(level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions, tick: tick))
            }
        }
        typealias Core = MicroscopicAuroraExperienceCore
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: openPlacements(heroLevel),
                          tick: Core.heroTick(heroLevel) ?? 0))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's placements applied and its tick
    /// shown (clamped to 0 … ticks swum), at the frame's time; no preview and not frozen.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> MicroscopicAuroraSceneSnapshot {
        let level: MicroscopicAuroraLevel = try MicroscopicAuroraExperienceCore.level(number: frame.level)
        var play: MicroscopicAuroraPlay = try MicroscopicAuroraExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return MicroscopicAuroraSceneSnapshot(play: play, shownTick: frame.tick, levelNumber: frame.level,
                                              time: frame.time)
    }

    /// An 8-bit sRGB colour.
    struct Colour: Codable, Equatable {
        /// Red, 0 … 255.
        let r: Int
        /// Green, 0 … 255.
        let g: Int
        /// Blue, 0 … 255.
        let b: Int
    }

    /// The counts of a description.
    struct Counts: Codable, Equatable {
        /// Stencil cells.
        let stencil: Int
        /// Lit stencil cells.
        let lit: Int
        /// Lit cells outside the stencil.
        let stray: Int
        /// Well sites.
        let sites: Int
        /// Placed wells.
        let wells: Int
        /// Swimmers.
        let swimmers: Int
        /// Ribbon points of every swimmer at the frame's tier.
        let ribbonPoints: Int
        /// Gauges (coverage and coherence).
        let gauges: Int
        /// Met gauges.
        let met: Int
        /// Lit actions bars.
        let litActions: Int
        /// Actions bars in all (the budget).
        let actions: Int
    }

    /// The description of one frame (see the file header). A position is `[x, y]` in 1/``quantum`` pixel, or null.
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
        /// The shown tick.
        let tick: Int
        /// The element counts.
        let counts: Counts
        /// The palette colours by name.
        let colours: [String: Colour]
        /// The dish centre.
        let dish: [Int]?
        /// Every swimmer at the shown tick, index order.
        let swimmers: [[Int]?]
        /// Every placed well, slot order.
        let wells: [[Int]?]
        /// Every site, index order.
        let sites: [[Int]?]
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
            try c.encode(tick, forKey: .tick)
            try c.encode(counts, forKey: .counts)
            try c.encode(colours, forKey: .colours)
            try c.encode(dish, forKey: .dish)
            try c.encode(swimmers, forKey: .swimmers)
            try c.encode(wells, forKey: .wells)
            try c.encode(sites, forKey: .sites)
            try c.encode(firstActionsBar, forKey: .firstActionsBar)
        }
    }

    /// `c` in 8 bits per channel, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// One channel 0 … 1 as a byte.
    static func byte(_ v: Double) -> Int {
        Int((min(max(v, 0), 1) * 255).rounded())
    }

    /// The palette colour named `name` (one of ``colourNames``): the palette constant of the same name.
    static func paletteColour(_ name: String) -> SIMD3<Double> {
        typealias Palette = MicroscopicAuroraPalette
        switch name {
        case "abyss": return Palette.abyss
        case "abyssTop": return Palette.abyssTop
        case "field": return Palette.field
        case "frond": return Palette.frond
        case "rim": return Palette.rim
        case "stencil": return Palette.stencil
        case "lit": return Palette.lit
        case "stray": return Palette.stray
        case "site": return Palette.site
        case "well": return Palette.well
        case "ribbon": return Palette.ribbon
        case "swimmer": return Palette.swimmer
        case "met": return Palette.met
        case "unmet": return Palette.unmet
        case "actionsLit": return Palette.actionsLit
        case "actionsUnlit": return Palette.actionsUnlit
        case "broken": return Palette.broken
        default: return Palette.glow
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project (behind the eye or
    /// not finite).
    static func position(_ point: SIMD3<Double>, camera: MicroscopicAuroraCamera) -> [Int]? {
        guard let p = MicroscopicAuroraSceneGeometry.project(point, camera: camera) else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The positions of `points` with `camera`.
    static func positions(_ points: [SIMD3<Double>], camera: MicroscopicAuroraCamera) -> [[Int]?] {
        var result: [[Int]?] = []
        for point in points { result.append(position(point, camera: camera)) }
        return result
    }

    /// The ribbon points of every swimmer of `snapshot` at `tier`.
    static func ribbonPointCount(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier) -> Int {
        var count: Int = 0
        for index in snapshot.positions.indices {
            count += MicroscopicAuroraSceneGeometry.ribbon(index, snapshot, tier: tier).count
        }
        return count
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        typealias G = MicroscopicAuroraSceneGeometry
        let snapshot: MicroscopicAuroraSceneSnapshot = try snapshot(frame)
        let tier: MicroscopicAuroraTier = MicroscopicAuroraTier.of(frame.tier)
        let camera: MicroscopicAuroraCamera = G.camera(aspect: Double(width) / Double(height))
        var swimmerPoints: [SIMD3<Double>] = []
        for index in snapshot.positions.indices { swimmerPoints.append(G.swimmerCentre(index, snapshot)) }
        var wellPoints: [SIMD3<Double>] = []
        for slot in snapshot.wells.indices {
            if let centre = G.wellCentre(slot, snapshot) { wellPoints.append(centre) }
        }
        var sitePoints: [SIMD3<Double>] = []
        for index in snapshot.sites.indices { sitePoints.append(G.siteCentre(index, snapshot)) }
        let won: Bool = snapshot.stage == .won
        var met: Int = 0
        if G.coverageMet(snapshot, won: won) { met += 1 }
        if G.coherenceMet(snapshot, won: won) { met += 1 }
        let actions: Int = max(snapshot.budget, 0)
        let firstBar: [Int]? = actions > 0 ? position(G.actionsBar(0, snapshot), camera: camera) : nil
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        let counts: Counts = Counts(stencil: snapshot.stencil.count, lit: snapshot.litStencil.count,
                                    stray: snapshot.stray.count, sites: snapshot.sites.count,
                                    wells: wellPoints.count, swimmers: snapshot.positions.count,
                                    ribbonPoints: ribbonPointCount(snapshot, tier: tier), gauges: gaugeCount,
                                    met: met, litActions: G.litActions(snapshot), actions: actions)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, tick: snapshot.shownTick, counts: counts, colours: colours,
                           dish: position(G.dishCentre(), camera: camera),
                           swimmers: positions(swimmerPoints, camera: camera),
                           wells: positions(wellPoints, camera: camera), sites: positions(sitePoints, camera: camera),
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
    /// (`MICROSCOPIC_AURORA_WRITE_GOLDEN=1`); otherwise touches nothing.
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
        if a.tick != b.tick { return "\(frame): tick \(a.tick), pinned tick \(b.tick)" }
        if a.counts != b.counts { return "\(frame): counts differ (pinned \(b.counts))" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if !near(a.dish, b.dish) { return "\(frame): dish centre at \(text(a.dish)) eighths, pinned \(text(b.dish))" }
        if let found = firstFar("swimmer", a.swimmers, b.swimmers) { return "\(frame): " + found }
        if let found = firstFar("well", a.wells, b.wells) { return "\(frame): " + found }
        if let found = firstFar("site", a.sites, b.sites) { return "\(frame): " + found }
        if !near(a.firstActionsBar, b.firstActionsBar) {
            return "\(frame): first actions bar at \(text(a.firstActionsBar)) eighths, pinned "
                + text(b.firstActionsBar)
        }
        return nil
    }

    /// The first position of `a` farther than one quantum from `b`'s, in words, or nil.
    static func firstFar(_ what: String, _ a: [[Int]?], _ b: [[Int]?]) -> String? {
        if a.count != b.count { return "\(a.count) \(what) points, pinned \(b.count)" }
        for index in a.indices where !near(a[index], b[index]) {
            return "\(what) \(index) at \(text(a[index])) eighths, pinned " + text(b[index])
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
