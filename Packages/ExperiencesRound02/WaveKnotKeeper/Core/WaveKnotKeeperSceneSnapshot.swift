// WaveKnotKeeperSceneSnapshot — feature 323 (R02-G03-03) T-R02G0303-002 (FR-R02G0303-002, 003, 004; clarifications
// Q1–Q4). What the renderer may read: an immutable copy of the kernel's state (the rope's points, the gates, the target,
// the projection summary and each projected crossing with its over-strand, the stage, the selected point and the level
// number) with the frame time, plus the palette and the three quality tiers. The renderer never holds the kernel, so no
// drawing result can change the game (renderer purity, R2-G03-INV-10).

import Foundation

/// The palette of Wave Knot Keeper, sRGB components 0 … 1 (clarification Q3).
public enum WaveKnotKeeperPalette {
    /// Night background, #05070F.
    public static let night = rgb(0x05, 0x07, 0x0F)
    /// Pearl, #E8E4DA (the glass body and the handles).
    public static let pearl = rgb(0xE8, 0xE4, 0xDA)
    /// Sapphire, #2F6FD8 (the glass tint and the gates).
    public static let sapphire = rgb(0x2F, 0x6F, 0xD8)
    /// Ember, #E0703A (caustic pulses and the selected handle).
    public static let ember = rgb(0xE0, 0x70, 0x3A)
    /// The four colours as hex strings, for the catalog: night, pearl, sapphire, ember.
    public static let hex: [String] = ["#05070F", "#E8E4DA", "#2F6FD8", "#E0703A"]

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only tube sides, corner samples and glow shells, never coordinates, objective or
/// indicators. Tiers are ordered richest first, as the shared quality contract requires: index n is the catalog's
/// `level-n` (the design's "Tier 0 D3-safe" is level-2).
public struct WaveKnotKeeperTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The tube's sides around its circumference.
    public let sides: Int
    /// The samples of each rounded corner.
    public let cornerSamples: Int
    /// The glow shells (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: sides 16/10/6, corner samples 8/4/2, glow shells 2/1/0.
    public static let all: [WaveKnotKeeperTier] = [
        WaveKnotKeeperTier(index: 0, sides: 16, cornerSamples: 8, glowShells: 2),
        WaveKnotKeeperTier(index: 1, sides: 10, cornerSamples: 4, glowShells: 1),
        WaveKnotKeeperTier(index: 2, sides: 6, cornerSamples: 2, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> WaveKnotKeeperTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// One proper crossing of the rope's xy-projection: the two segments, the one passing over (larger z at the crossing)
/// and the projected crossing point in kernel units.
public struct WaveKnotKeeperCrossingMark: Sendable, Equatable, Hashable {
    /// The lower segment index (segment i joins point i to point i + 1, the last to the first).
    public let first: Int
    /// The higher segment index.
    public let second: Int
    /// The segment passing over, `first` or `second`.
    public let over: Int
    /// The crossing's x in kernel units.
    public let x: Double
    /// The crossing's y in kernel units.
    public let y: Double

    /// A mark of the given values (not checked).
    public init(first: Int, second: Int, over: Int, x: Double, y: Double) {
        self.first = first
        self.second = second
        self.over = over
        self.x = x
        self.y = y
    }

    /// Every proper crossing of `points`' projection, in the summary's pair order; degenerate meetings are left out.
    public static func marks(_ points: [WaveKnotKeeperPoint]) -> [WaveKnotKeeperCrossingMark] {
        let n = points.count
        guard n >= 4 else { return [] }
        var result: [WaveKnotKeeperCrossingMark] = []
        for i in 0..<(n - 2) {
            for j in stride(from: i + 2, to: n, by: 1) {
                if i == 0 && j == n - 1 { continue }
                let p1 = points[i], q1 = points[(i + 1) % n], p2 = points[j], q2 = points[(j + 1) % n]
                guard case .signed = WaveKnotKeeperGeometry.crossing(p1, q1, p2, q2) else { continue }
                // p1 + t·d1 = p2 + u·d2 (exact integers, then one division for the point).
                let d1x = q1.x - p1.x, d1y = q1.y - p1.y, d2x = q2.x - p2.x, d2y = q2.y - p2.y
                let den = d1x * d2y - d1y * d2x
                let wx = p2.x - p1.x, wy = p2.y - p1.y
                let tn = wx * d2y - wy * d2x
                let un = wx * d1y - wy * d1x
                let z1 = p1.z * den + tn * (q1.z - p1.z)
                let z2 = p2.z * den + un * (q2.z - p2.z)
                let firstOver = (z1 - z2) * (den > 0 ? 1 : -1) > 0
                let t = Double(tn) / Double(den)
                result.append(WaveKnotKeeperCrossingMark(first: i, second: j, over: firstOver ? i : j,
                                                         x: Double(p1.x) + t * Double(d1x),
                                                         y: Double(p1.y) + t * Double(d1y)))
            }
        }
        return result
    }
}

/// An immutable copy of a play for drawing.
public struct WaveKnotKeeperSceneSnapshot: Sendable, Equatable {
    /// The caustic pulse frequency in hertz (clarification Q1).
    public static let pulseHertz = 0.5

    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The rope's control points.
    public let points: [WaveKnotKeeperPoint]
    /// The level's crossing gates.
    public let gates: [WaveKnotKeeperGate]
    /// The level's target signature.
    public let target: WaveKnotKeeperTarget
    /// The projection summary of the rope.
    public let summary: WaveKnotKeeperSummary
    /// The proper crossings of the projection with their over-strands.
    public let crossings: [WaveKnotKeeperCrossingMark]
    /// The play's stage.
    public let stage: WaveKnotKeeperStage
    /// The selected control point, if any (presentation only).
    public let selected: Int?
    /// The presentation time in seconds (not a kernel quantity; 0 under Reduce Motion).
    public let time: Double

    /// A snapshot of `play` at presentation time `time` (a non-finite time counts as 0); `selected` outside the rope
    /// counts as none.
    public init(play: WaveKnotKeeperPlay, levelNumber: Int, selected: Int? = nil, time: Double) {
        self.levelNumber = levelNumber
        points = play.points
        gates = play.level.gates
        target = play.level.target
        summary = WaveKnotKeeperGeometry.summary(play.points)
        crossings = WaveKnotKeeperCrossingMark.marks(play.points)
        stage = play.stage
        if let selected, play.points.indices.contains(selected) { self.selected = selected } else { self.selected = nil }
        self.time = time.isFinite ? time : 0
    }

    /// `snapshot` with its crossing marks replaced by `crossings` (every other field kept): the tests' seam for drawing
    /// crossings that fade in and out on the same rope (feature 326, T-R02G0306-004). Internal; never drawn by the app.
    init(_ snapshot: WaveKnotKeeperSceneSnapshot, crossings: [WaveKnotKeeperCrossingMark]) {
        levelNumber = snapshot.levelNumber
        points = snapshot.points
        gates = snapshot.gates
        target = snapshot.target
        summary = snapshot.summary
        self.crossings = crossings
        stage = snapshot.stage
        selected = snapshot.selected
        time = snapshot.time
    }

    /// The caustic pulse brightness 0 … 1 at the snapshot's time: 0.5 + 0.5 sin(2π · 0.5 · time).
    public var pulse: Double {
        0.5 + 0.5 * sin(2 * Double.pi * Self.pulseHertz * time)
    }

    /// Whether the rope's signature matches the target (the kernel's win condition, for display only).
    public var matchesTarget: Bool {
        !summary.degenerate && summary.crossings == target.crossings && summary.writhe == target.writhe
    }
}
