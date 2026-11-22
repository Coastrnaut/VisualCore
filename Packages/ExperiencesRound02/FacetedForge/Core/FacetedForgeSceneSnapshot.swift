// FacetedForgeSceneSnapshot — feature 373 (R02-G08-03) T-R02G0803-002 (FR-R02G0803-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — every piece's corners in world space
// (the crystal's corner centroid subtracted, divided by R, the largest centroid-to-corner distance, so the crystal fits
// the unit sphere), its faces as corner index lists in the kernel's anticlockwise order with a cut flag (a face whose
// plane is not one of the crystal's half-spaces) and its centroid — with the preview choice (piece, direction, depth)
// and the chosen piece's cross-section, the stage, the failure and its piece, the cuts spent, the budget, the level
// number and the presentation time; plus the palette and the three quality tiers. The kernel's exact corners are
// turned into Doubles once here; no rule is evaluated on Doubles. The renderer never holds the kernel, so no drawing
// result can change the game (renderer purity).
import Foundation

/// The palette of Faceted Forge, sRGB components 0 … 1 (clarification Q3; the design's "ice glass, ruby, inner amber").
public enum FacetedForgePalette {
    /// The dark ground, #07090F.
    public static let ground = rgb(0x07, 0x09, 0x0F)
    /// The ice-glass original faces, #BFE6F5.
    public static let ice = rgb(0xBF, 0xE6, 0xF5)
    /// The fresnel highlight of the glass, #F2FBFF.
    public static let highlight = rgb(0xF2, 0xFB, 0xFF)
    /// The ruby preview plane and the rim of the cut faces, #C8163C.
    public static let ruby = rgb(0xC8, 0x16, 0x3C)
    /// The incandescent inner amber of the cut faces, #FFB347.
    public static let amber = rgb(0xFF, 0xB3, 0x47)
    /// The lattice drawn on the cut faces, #FFE2A8.
    public static let lattice = rgb(0xFF, 0xE2, 0xA8)
    /// The cross on a sliver piece, #FF4D6D.
    public static let sliver = rgb(0xFF, 0x4D, 0x6D)
    /// A spent bar of the cut mark, #C8163C.
    public static let spent = rgb(0xC8, 0x16, 0x3C)
    /// An unspent bar of the cut mark, #3A4558.
    public static let unspent = rgb(0x3A, 0x45, 0x58)

    /// The catalog palette as hex strings: ground, ice, ruby, amber, lattice.
    public static let hex: [String] = ["#07090F", "#BFE6F5", "#C8163C", "#FFB347", "#FFE2A8"]

    /// The colour of `r`, `g`, `b` bytes.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only the bevel segments, the dispersion layers and the glow shells, never pieces,
/// faces, the preview plane, colours, marks or positions. Tiers are ordered richest first: index n is the catalog's `level-n`
/// (the design's "Tier 0 D3-safe" is level-2).
public struct FacetedForgeTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The bevel segments per piece edge.
    public let bevelSegments: Int
    /// The faux-dispersion layers of the glass shader.
    public let dispersionLayers: Int
    /// The glow shells over the cut faces (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: 3/2/1 bevel segments, 3/2/1 dispersion layers, 2/1/0 glow shells.
    public static let all: [FacetedForgeTier] = [
        FacetedForgeTier(index: 0, bevelSegments: 3, dispersionLayers: 3, glowShells: 2),
        FacetedForgeTier(index: 1, bevelSegments: 2, dispersionLayers: 2, glowShells: 1),
        FacetedForgeTier(index: 2, bevelSegments: 1, dispersionLayers: 1, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> FacetedForgeTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// The preview choice of the controls: the piece, direction and depth of the next cut. It is presentation state, never
/// kernel state (clarification Q5).
public struct FacetedForgePreviewChoice: Sendable, Equatable, Hashable {
    /// The chosen piece's index in the canonical order.
    public let piece: Int
    /// The chosen direction, 0 … 12.
    public let direction: Int
    /// The chosen depth, −24 … 24.
    public let depth: Int

    /// A choice of the given values (the direction clamped to 0 … 12 and the depth to −24 … 24; the piece to ≥ 0).
    public init(piece: Int, direction: Int, depth: Int) {
        self.piece = max(piece, 0)
        self.direction = min(max(direction, 0), FacetedForgeDirection.all.count - 1)
        self.depth = min(max(depth, FacetedForgeHalfSpace.depths.lowerBound), FacetedForgeHalfSpace.depths.upperBound)
    }

    /// The direction of the default choice: 2, the z axis, whose plane faces the authored camera (feature 374,
    /// R02-G08-04: the x axis of feature 373 was seen edge-on, so a tap on the plane could not commit).
    public static let facingDirection: Int = 2

    /// The default choice for `play`: piece 0, ``facingDirection`` and the middle depth among those whose plane
    /// crosses it.
    public static func initial(_ play: FacetedForgePlay) -> FacetedForgePreviewChoice {
        let direction: Int = facingDirection
        guard let first = play.pieces.first else {
            return FacetedForgePreviewChoice(piece: 0, direction: direction, depth: 0)
        }
        let crossing: [Int] = FacetedForgeSolver.crossingDepths(first, direction: direction)
        let depth: Int = crossing.isEmpty ? 0 : crossing[crossing.count / 2]
        return FacetedForgePreviewChoice(piece: 0, direction: direction, depth: depth)
    }

    /// This choice made valid for `play`: the piece clamped to the piece count and the depth moved to the nearest depth
    /// whose plane crosses that piece (the smaller one on a tie; unchanged when none crosses).
    public func clamped(to play: FacetedForgePlay) -> FacetedForgePreviewChoice {
        let index: Int = min(piece, max(play.pieces.count - 1, 0))
        guard play.pieces.indices.contains(index) else { return self }
        let crossing: [Int] = FacetedForgeSolver.crossingDepths(play.pieces[index], direction: direction)
        var chosen: Int = depth
        if let nearest = crossing.min(by: { abs($0 - depth) < abs($1 - depth) }) { chosen = nearest }
        return FacetedForgePreviewChoice(piece: index, direction: direction, depth: chosen)
    }

    /// The choice moved by `step` crossing depths (clamped to the crossing range of the chosen piece).
    public func steppingDepth(_ step: Int, in play: FacetedForgePlay) -> FacetedForgePreviewChoice {
        guard play.pieces.indices.contains(piece) else { return self }
        let crossing: [Int] = FacetedForgeSolver.crossingDepths(play.pieces[piece], direction: direction)
        guard let at = crossing.firstIndex(of: depth) else { return clamped(to: play) }
        let next: Int = min(max(at + step, 0), crossing.count - 1)
        return FacetedForgePreviewChoice(piece: piece, direction: direction, depth: crossing[next])
    }
}

/// An immutable copy of everything the renderer may read about one Faceted Forge play at one frame.
public struct FacetedForgeSceneSnapshot: Sendable, Equatable {
    /// A piece as the renderer sees it, in world space before the opening.
    public struct Piece: Sendable, Equatable {
        /// The corners, in the kernel's sorted order.
        public let corners: [SIMD3<Double>]
        /// The faces as corner index lists, anticlockwise seen from outside.
        public let faces: [[Int]]
        /// Whether each face is a cut face (its plane is not one of the crystal's half-spaces).
        public let cutFaces: [Bool]
        /// The mean of the corners.
        public let centroid: SIMD3<Double>
    }

    /// The pieces, in the kernel's canonical order.
    public let pieces: [Piece]
    /// R: the largest distance, in kernel units, from the crystal's corner centroid to one of its corners.
    public let scale: Double
    /// The preview choice.
    public let choice: FacetedForgePreviewChoice
    /// The chosen piece's cross-section by the chosen plane, ordered around its centre (empty when the plane misses).
    public let preview: [SIMD3<Double>]
    /// The play's stage.
    public let stage: FacetedForgeStage
    /// Why the play failed, if it did.
    public let failure: FacetedForgeFailure?
    /// The sliver piece of a sliver failure, if any.
    public let failurePiece: Int?
    /// The cuts spent.
    public let cuts: Int
    /// The level's cut budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (shimmer and opening only; never read by the rules).
    public let time: Double

    /// Whether the pieces match the target (the opening is then full, 0.2).
    public var won: Bool { stage == .won || (stage == .result && failure == nil) }

    /// A snapshot of `play` with the preview `choice` at presentation time `time` (non-finite times become 0).
    public init(play: FacetedForgePlay, levelNumber: Int, choice: FacetedForgePreviewChoice, time: Double) {
        let crystal: FacetedForgePiece = play.level.crystal
        let raw: [SIMD3<Double>] = crystal.corners.map(Self.vector)
        let centre: SIMD3<Double> = raw.reduce(SIMD3<Double>(0, 0, 0), +) / Double(max(raw.count, 1))
        var r: Double = 0
        for p in raw { r = max(r, ((p - centre) * (p - centre)).sum().squareRoot()) }
        let scale: Double = r > 0 ? r : 1
        let original: Set<FacetedForgeHalfSpace> = Set(crystal.halfSpaces)
        func world(_ p: FacetedForgePoint) -> SIMD3<Double> { (Self.vector(p) - centre) / scale }
        pieces = play.pieces.map { piece in
            let corners: [SIMD3<Double>] = piece.corners.map(world)
            var index: [FacetedForgePoint: Int] = [:]
            for (i, p) in piece.corners.enumerated() { index[p] = i }
            let faces: [[Int]] = piece.faces.map { face in face.corners.compactMap { index[$0] } }
            let cut: [Bool] = piece.faces.map { !original.contains($0.plane) }
            let centroid: SIMD3<Double> = corners.reduce(SIMD3<Double>(0, 0, 0), +) / Double(max(corners.count, 1))
            return Piece(corners: corners, faces: faces, cutFaces: cut, centroid: centroid)
        }
        self.scale = scale
        self.choice = choice
        if play.pieces.indices.contains(choice.piece),
           play.pieces[choice.piece].isCrossed(direction: choice.direction, depth: choice.depth) {
            preview = Self.section(play.pieces[choice.piece], direction: choice.direction, depth: choice.depth)
                .map { ($0 - centre) / scale }
        } else {
            preview = []
        }
        stage = play.stage
        failure = play.failure
        if case .sliver(let piece, _) = play.failure { failurePiece = piece } else { failurePiece = nil }
        cuts = play.cuts
        budget = play.level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? time : 0
    }

    /// The kernel point `p` as Doubles (numerator / denominator).
    static func vector(_ p: FacetedForgePoint) -> SIMD3<Double> {
        SIMD3(Double(p.x.numerator) / Double(p.x.denominator), Double(p.y.numerator) / Double(p.y.denominator),
              Double(p.z.numerator) / Double(p.z.denominator))
    }

    /// The cross-section of `piece` by the plane n·p = depth of `direction`, in kernel units, ordered by angle around
    /// its centre in the plane (the corners on the plane and the crossings of every edge that straddles it).
    static func section(_ piece: FacetedForgePiece, direction: Int, depth: Int) -> [SIMD3<Double>] {
        let d: FacetedForgeDirection = FacetedForgeDirection.all[direction]
        let n: SIMD3<Double> = SIMD3(Double(d.x), Double(d.y), Double(d.z))
        let k: Double = Double(depth)
        var points: [SIMD3<Double>] = []
        func add(_ p: SIMD3<Double>) {
            if !points.contains(where: { (($0 - p) * ($0 - p)).sum() < 1e-18 }) { points.append(p) }
        }
        for edge in piece.edges {
            let a: SIMD3<Double> = vector(edge[0])
            let b: SIMD3<Double> = vector(edge[1])
            let va: Double = (n * a).sum() - k
            let vb: Double = (n * b).sum() - k
            if abs(va) < 1e-12 { add(a) }
            if abs(vb) < 1e-12 { add(b) }
            if (va < -1e-12 && vb > 1e-12) || (va > 1e-12 && vb < -1e-12) { add(a + (b - a) * (va / (va - vb))) }
        }
        guard points.count >= 3 else { return [] }
        let centre: SIMD3<Double> = points.reduce(SIMD3<Double>(0, 0, 0), +) / Double(points.count)
        let u0: SIMD3<Double> = abs(n.x) < 0.5 ? SIMD3(1, 0, 0) : SIMD3(0, 1, 0)
        let u: SIMD3<Double> = cross(n, u0)
        let v: SIMD3<Double> = cross(n, u)
        return points.sorted { lhs, rhs in
            atan2(((lhs - centre) * v).sum(), ((lhs - centre) * u).sum())
                < atan2(((rhs - centre) * v).sum(), ((rhs - centre) * u).sum())
        }
    }

    /// The cross product of `a` and `b`.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
}
