// MoonlitMechanismSceneGeometry — feature 433 (R02-G14-03) T-R02G1403-004 (FR-R02G1403-001, 002, 003, 004, 006;
// clarifications Q1, Q2, Q3, Q4). The clockwork of Moonlit Mechanism, built from a snapshot only. x points right, y up
// and z towards the viewer. The paper wall is the plane z = −0.6 facing the camera; its cell size is
// s = min(1.8 / W, 1.2 / H) and cell (c, r) (cell number r · W + c, rows counted downward) is centred at
// x = (c − (W − 1)/2) · s, y = 0.65 − (r − (H − 1)/2) · s.
//
// Draw order (clarification Q1; depth testing off, so the clockwork mesh is in painter's order):
//   1. the night backdrop, a plane at z = −0.62 over x −1.2 … 1.2, y −0.5 … 1.7;
//   2. the paper wall, the W × H rectangle (on a won level the shader brightens it by `u_won`, the fallback colour is
//      lifted by ``wonLift`` and the glow gains a wall shell; nothing moves);
//   3. at tiers with a soft edge, a feather band 0.15 s wide around every ink square (``Material/inkFeather``);
//   4. the shown key frame's cast cells (the kernel's, ``MoonlitMechanismSceneSnapshot/cast``) as ink squares of side
//      0.92 s;
//   5. the shown key frame's target cells' borders, 0.08 s wide inside each cell (``Material/targetOutline``);
//   6. the missing target cells (``MoonlitMechanismSceneSnapshot/missingCells``) as an outline band
//      0.28 s … 0.38 s from the cell's centre, dotted by the shader (``Material/missingDotted``);
//   7. the stray cells (``MoonlitMechanismSceneSnapshot/strayCells``) as squares of side 0.92 s, hatched by the shader
//      (``Material/strayHatch``);
//   8. the forbidden cells crossed: two diagonal strips 0.1 s wide, inset 0.15 s from the corners
//      (``Material/forbiddenMark``), and a `forbidden` failure's cell outlined by a band 0.04 s … 0.14 s outside it
//      (``Material/broken``);
//   9. the gauges on the plane z = −0.6: one key-frame card per key frame at y = −0.18 in equal slots across
//      x −0.6 … 0.6 (min(0.16, 0.8 · slot) × 0.07; the unlit card, then from its left edge the lit share equal to the
//      key frame's covered fraction, then for a required key frame a gold border 0.006 wide; the shown card raised by
//      0.02; a `missing` or `stray` failure's card outlined 0.006 … 0.014 outside it in ``Material/broken``); one
//      alignment pip per mesh (gear 1 … n − 1) at y = −0.30 in equal slots across x −0.3 … 0.3 (side
//      min(0.04, 0.6 · slot)), filled when the mesh is aligned, else an outline a fifth of the side wide;
//      `budget` moves bars at y = −0.40 in equal slots across x −0.9 … 0.9 (each slot 1.8 / budget wide, the bar
//      four fifths of it — a fifth gap — and 0.04 tall), the first `actionsLeft` lit;
//  10. the gears back to front (ascending plane z = −0.6 + 0.12 · depth, then index): gear i centred on its centre
//      cell (the lamp moves only its shadow, as the kernel casts it), its translucent body a disc of radius R − 0.3 s
//      (``Material/gearBody``), the rim band from R − 0.3 s to the toothed outline of radius R = 3.4 s with T teeth of
//      height 0.35 s (``Material/gearRim``; each tooth period of `tier.segmentsPerTooth` outline segments sampling a
//      trapezoid profile, base ±1/3 and top ±1/6 of the period), the tooth-zero notch (a radial strip 0.12 s wide from
//      R − 0.3 s to R + 0.6 · 0.35 s, ``Material/gearNotch``) and the solid blades at the drawn phases as translucent
//      spokes 0.3 s wide from 0.35 s to 0.7 R along the direction of their slot's offsets (``Material/blade``); then a
//      `jammed` failure's pair outlined by an arc band 0.02 s … 0.1 s beyond the tooth tips spanning ±1.5 teeth towards
//      the other gear, on both gears (``Material/broken``);
//  11. the lamp's height ladder (`lampHeights` rungs 0.05 wide and 0.008 tall at x = 0.12, y = 1.30 + 0.03 · k, and two
//      rails 0.006 wide, ``Material/ladder``) and the lamp, a disc of radius 0.06 at (0, 1.30 + 0.03 · height, 0.35)
//      (``Material/lamp``).
// The glow mesh is drawn last, additively: `tier.glowShells` shells k (outermost first), each a band from the object's
// edge grown by k growths, around the lamp (0.03 per shell), around every card with a covered fraction above 0 (0.012
// per shell) and, on a won level only, around the paper wall (0.04 per shell), lifted 0.001 · k; empty at level-2.
//
// Rotation: tooth k (counted clockwise from tooth zero) of gear i points at the angle
// π/2 − (phase + k) · 360° / T (at phase 0 tooth zero points up), so a gear is rotated by phase · 360° / T clockwise.
// A handle turn moves a gear's phase by its direction (``MoonlitMechanismTrain/direction(_:_:)``), so on a turn a
// direction +1 gear turns clockwise and a direction −1 gear anticlockwise (``turnSense(_:_:)``), and the teeth move the
// same way as the blades step through the slot table.
//
// Vertex streams (attributes a_position, a_normal, a_uv; the contract with `MoonlitMechanismShaders`, whose
// ``MoonlitMechanismShaders/Material`` gives the codes). Clockwork: a_uv.x is the material code and a_uv.y the local
// coordinate d: strips (target borders, the missing outline, forbidden crosses, the rim band, the notch, spokes, ladder
// rails and rungs, card borders, unlit pip outlines and broken outlines) −1 on one long side and +1 on the other; fans
// (ink squares, stray squares, gear bodies, the lamp, cards and their lit share, lit pips and moves bars) 0 at the
// centre vertex and 1 on the outline; feathers 0 on the ink square's edge and 1 on the outer edge; the backdrop and the
// paper 0. a_normal is (0, 0, 1) everywhere (not read by the clockwork shader). Glow: a_normal is the colour
// (``MoonlitMechanismPalette/lampGlow`` for the lamp, ``MoonlitMechanismPalette/glow`` for cards and the wall), a_uv.x
// = 2 · kind + factor (``GlowKind``: lamp 0, card 1, wall 2; factor 0.5^k, times the covered fraction for a card) and
// a_uv.y the shell's radial coordinate, 0 on its inner edge and 1 on its outer edge. Every triangle winds
// counter-clockwise seen from +z. Tiers change only the gears' outline segments, the feathers and the glow: every
// position named above is the same at every tier. Reduce Motion draws the gears at the set-up phases of the shown key
// frame (``MoonlitMechanismSceneSnapshot/phases``) without a turning preview; this geometry never previews a turn, so
// both draw the same phases. Doubles are used for drawing only; nothing here is consulted by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct MoonlitMechanismCamera: Sendable, Equatable {
    /// The eye position in world units, (0, 0.65, 2.4).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, 0.55, −0.3).
    public let target: SIMD3<Double>
    /// The vertical field of view in radians (fitted to the authored box at `aspect`).
    public let fovY: Double
    /// The width-to-height ratio used (sanitised to 0.1 … 10).
    public let aspect: Double
    /// The near plane distance.
    public let near: Double
    /// The far plane distance.
    public let far: Double
    /// The view matrix.
    public let view: Mat4
    /// The projection matrix.
    public let projection: Mat4
    /// projection · view (upload with `.floats`).
    public let viewProjection: Mat4
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct MoonlitMechanismColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Moonlit Mechanism scene from a `MoonlitMechanismSceneSnapshot`: places, meshes, camera and projection.
public enum MoonlitMechanismSceneGeometry {
    /// The material codes (shared with the shaders).
    public typealias Material = MoonlitMechanismShaders.Material

    // MARK: Constants (world units, or shares of the cell size s where stated)

    /// The wall's plane.
    public static let wallZ: Double = -0.6
    /// The widest the wall may be: s ≤ 1.8 / W.
    public static let wallSpan: Double = 1.8
    /// The tallest the wall may be: s ≤ 1.2 / H.
    public static let wallTall: Double = 1.2
    /// The height of the wall's centre.
    public static let wallCentreY: Double = 0.65
    /// The backdrop's plane.
    public static let backdropZ: Double = -0.62
    /// The backdrop's extent along x.
    public static let backdropX: ClosedRange<Double> = -1.2...1.2
    /// The backdrop's extent along y.
    public static let backdropY: ClosedRange<Double> = -0.5...1.7
    /// An ink square's side, in s.
    public static let inkSide: Double = 0.92
    /// A feather band's width, in s.
    public static let featherWidth: Double = 0.15
    /// A target border's width inside its cell, in s.
    public static let targetLine: Double = 0.08
    /// A missing cell's outline band (dotted by the shader): half sizes from the cell's centre, in s.
    public static let missingBand: ClosedRange<Double> = 0.28...0.38
    /// A forbidden cross's strip width, in s.
    public static let crossWidth: Double = 0.1
    /// A forbidden cross's inset from the cell's corners, in s.
    public static let crossInset: Double = 0.15
    /// A `forbidden` failure's outline: distances beyond the cell's half side, in s.
    public static let cellOutline: ClosedRange<Double> = 0.04...0.14
    /// The plane of the shallowest gear before its depth: z = −0.6 + 0.12 · depth.
    public static let gearBaseZ: Double = -0.6
    /// The plane step per depth.
    public static let gearDepthStep: Double = 0.12
    /// The rim's radius R, in s.
    public static let rimRadius: Double = 3.4
    /// A tooth's height, in s.
    public static let toothHeight: Double = 0.35
    /// The rim band's width inside R, in s.
    public static let rimBand: Double = 0.3
    /// Where the spokes end, as a share of R.
    public static let bodyInner: Double = 0.7
    /// Where the spokes start, in s.
    public static let hubRadius: Double = 0.35
    /// A won wall's glow shell growth per shell beyond the paper's edge.
    public static let wallGlowGrowth: Double = 0.04
    /// A spoke's width, in s.
    public static let spokeWidth: Double = 0.3
    /// The notch's width, in s.
    public static let notchWidth: Double = 0.12
    /// How far the notch reaches beyond R, as a share of the tooth height.
    public static let notchReach: Double = 0.6
    /// A tooth's base half-width as a share of its period.
    public static let toothBase: Double = 1.0 / 3.0
    /// A tooth's top half-width as a share of its period.
    public static let toothTop: Double = 1.0 / 6.0
    /// The rim check point's distance inside R, in s.
    public static let checkInset: Double = 0.2
    /// The rim check point's angle past the tooth-zero notch, in teeth.
    public static let checkTooth: Double = 0.5
    /// A `jammed` failure's arc band: distances beyond the tooth tips, in s.
    public static let jamBand: ClosedRange<Double> = 0.02...0.1
    /// A `jammed` failure's arc: half its span, in teeth.
    public static let jamSpan: Double = 1.5
    /// A `jammed` failure's arc segments.
    public static let jamSegments: Int = 8
    /// The lamp's x.
    public static let lampX: Double = 0
    /// The lamp's y at height 0.
    public static let lampBaseY: Double = 1.30
    /// The lamp's rise per height.
    public static let lampStep: Double = 0.03
    /// The lamp's plane.
    public static let lampZ: Double = 0.35
    /// The lamp's radius.
    public static let lampRadius: Double = 0.06
    /// The lamp disc's segments (and its glow discs').
    public static let lampSegments: Int = 24
    /// The ladder's centre x.
    public static let ladderX: Double = 0.12
    /// A rung's width.
    public static let rungWidth: Double = 0.05
    /// A rung's height.
    public static let rungLine: Double = 0.008
    /// A rail's width.
    public static let railWidth: Double = 0.006
    /// The gauges' plane.
    public static let gaugeZ: Double = -0.6
    /// The cards' centre line.
    public static let cardY: Double = -0.18
    /// The cards' left end.
    public static let cardStart: Double = -0.6
    /// The cards' right end.
    public static let cardEnd: Double = 0.6
    /// A card's widest.
    public static let cardWidthMax: Double = 0.16
    /// A card's height.
    public static let cardHeight: Double = 0.07
    /// The shown card's rise.
    public static let cardRaise: Double = 0.02
    /// A required card's border width.
    public static let borderLine: Double = 0.006
    /// A failing card's outline: distances beyond the card's edges.
    public static let cardOutline: ClosedRange<Double> = 0.006...0.014
    /// The pips' centre line.
    public static let pipY: Double = -0.30
    /// The pips' left end.
    public static let pipStart: Double = -0.3
    /// The pips' right end.
    public static let pipEnd: Double = 0.3
    /// A pip's largest side.
    public static let pipSideMax: Double = 0.04
    /// A pip's side as a share of its slot when the slot is narrow.
    public static let pipFill: Double = 0.6
    /// An unlit pip's outline width as a share of its side.
    public static let pipLine: Double = 0.2
    /// The moves bars' centre line.
    public static let movesY: Double = -0.40
    /// The moves bars' left end.
    public static let movesStart: Double = -0.9
    /// The moves bars' right end.
    public static let movesEnd: Double = 0.9
    /// The share of a slot a card or a moves bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// A moves bar's height.
    public static let barHeight: Double = 0.04
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// Extra radius per glow shell around the lamp.
    public static let lampGlowGrowth: Double = 0.03
    /// Extra half size per glow shell around a card.
    public static let cardGlowGrowth: Double = 0.012
    /// Lift towards the viewer per glow shell.
    public static let glowLift: Double = 0.001
    /// How far a won level lifts the paper's fallback colour towards white.
    public static let wonLift: Double = 0.4
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, 0.65, 2.4)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, 0.55, -0.3)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-0.95, -0.45, -0.6)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(0.95, 1.5, 0.4)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places (the CPU reference)

    /// The cell size s = min(1.8 / W, 1.2 / H).
    public static func cellSize(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        min(wallSpan / Double(max(snapshot.width, 1)), wallTall / Double(max(snapshot.rows, 1)))
    }

    /// The point of wall column `column` and row `row` (fractional allowed): ((c − (W − 1)/2) · s,
    /// 0.65 − (r − (H − 1)/2) · s, −0.6).
    public static func wallPoint(column: Double, row: Double,
                                 _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        let s: Double = cellSize(snapshot)
        let x: Double = (column - Double(snapshot.width - 1) / 2) * s
        let y: Double = wallCentreY - (row - Double(snapshot.rows - 1) / 2) * s
        return SIMD3(x, y, wallZ)
    }

    /// The centre of cell number `cell` (row · W + column) on the wall.
    public static func cellCentre(_ cell: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        let width: Int = max(snapshot.width, 1)
        let column: Int = MoonlitMechanismTrain.mod(cell, width)
        let row: Int = (cell - column) / width
        return wallPoint(column: Double(column), row: Double(row), snapshot)
    }

    /// `index` clamped to 0 … count − 1 (0 when count is 0).
    static func clamped(_ index: Int, _ count: Int) -> Int { min(max(index, 0), max(count - 1, 0)) }

    /// The plane of gear `index` (clamped): z = −0.6 + 0.12 · depth.
    public static func gearZ(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        guard !snapshot.gears.isEmpty else { return wallZ }
        return gearBaseZ + gearDepthStep * Double(snapshot.gears[clamped(index, snapshot.gears.count)].depth)
    }

    /// The centre of gear `index` (clamped): its centre cell's x and y (never shifted by the lamp) on its plane.
    public static func gearCentre(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.gears.isEmpty else { return SIMD3(0, wallCentreY, wallZ) }
        let centre: MoonlitMechanismCell = snapshot.gears[clamped(index, snapshot.gears.count)].centre
        let p: SIMD3<Double> = wallPoint(column: Double(centre.column), row: Double(centre.row), snapshot)
        return SIMD3(p.x, p.y, gearZ(index, snapshot))
    }

    /// The phases the gears are drawn at: the shown key frame's (``MoonlitMechanismSceneSnapshot/phases``), with or
    /// without Reduce Motion (this geometry never previews a turn).
    public static func drawnPhases(_ snapshot: MoonlitMechanismSceneSnapshot, reduceMotion: Bool) -> [Int] {
        _ = reduceMotion
        return snapshot.phases
    }

    /// The angle in radians of tooth `tooth` (fractional allowed; counted clockwise from tooth zero) of gear `index`
    /// at the drawn phases: π/2 − (phase + tooth) · 2π / T.
    public static func toothAngle(_ index: Int, tooth: Double, _ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        guard !snapshot.gears.isEmpty else { return Double.pi / 2 }
        let i: Int = clamped(index, snapshot.gears.count)
        let teeth: Int = max(snapshot.gears[i].teeth, 1)
        let phase: Int = i < snapshot.phases.count ? snapshot.phases[i] : 0
        return Double.pi / 2 - (Double(phase) + tooth) * 2 * Double.pi / Double(teeth)
    }

    /// The sense gear `index` turns on a handle turn of +1: +1 clockwise (direction +1), −1 anticlockwise
    /// (direction −1), per ``MoonlitMechanismTrain/direction(_:_:)``.
    public static func turnSense(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> Int {
        guard !snapshot.gears.isEmpty else { return 1 }
        return MoonlitMechanismTrain.direction(snapshot.gears, clamped(index, snapshot.gears.count))
    }

    /// The rim radius R = 3.4 s.
    public static func rimRadius(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double { rimRadius * cellSize(snapshot) }

    /// The frame-check point of gear `index`'s rim (clarification Q3): at the angle of its tooth-zero notch plus half
    /// a tooth (between teeth 0 and 1, clear of the notch), 0.2 s inside R (on the rim band, clear of the spokes, which
    /// end at 0.7 R).
    public static func gearRimCheckPoint(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        let a: Double = toothAngle(index, tooth: checkTooth, snapshot)
        let r: Double = rimRadius(snapshot) - checkInset * cellSize(snapshot)
        return gearCentre(index, snapshot) + SIMD3(cos(a) * r, sin(a) * r, 0)
    }

    /// The width of one card slot, 1.2 / key frames.
    public static func cardSlot(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        (cardEnd - cardStart) / Double(max(snapshot.keyFrames.count, 1))
    }

    /// A card's width, min(0.16, 0.8 · slot).
    public static func cardWidth(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        min(cardWidthMax, barFill * cardSlot(snapshot))
    }

    /// The centre of key-frame card `index`: (−0.6 + (index + 0.5) · slot, −0.18, −0.6), raised by 0.02 for the
    /// shown key frame.
    public static func card(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        let raise: Double = index == snapshot.shownFrame ? cardRaise : 0
        return SIMD3(cardStart + (Double(index) + 0.5) * cardSlot(snapshot), cardY + raise, gaugeZ)
    }

    /// The covered fraction of key frame `index` clamped to 0 … 1 (0 for an index outside the report).
    public static func cardFraction(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        guard index >= 0, index < snapshot.report.frames.count else { return 0 }
        let f: Double = snapshot.coveredFraction(index)
        return f.isFinite ? min(max(f, 0), 1) : 0
    }

    /// The number of alignment pips: one per mesh (gears 1 … n − 1).
    public static func pipCount(_ snapshot: MoonlitMechanismSceneSnapshot) -> Int { max(snapshot.gears.count - 1, 0) }

    /// The width of one pip slot, 0.6 / meshes.
    public static func pipSlot(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        (pipEnd - pipStart) / Double(max(pipCount(snapshot), 1))
    }

    /// A pip's side, min(0.04, 0.6 · slot).
    public static func pipSide(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        min(pipSideMax, pipFill * pipSlot(snapshot))
    }

    /// The centre of alignment pip `index` (the mesh of gear index + 1 with its parent):
    /// (−0.3 + (index + 0.5) · slot, −0.30, −0.6).
    public static func alignmentPip(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        SIMD3(pipStart + (Double(index) + 0.5) * pipSlot(snapshot), pipY, gaugeZ)
    }

    /// Whether alignment pip `index` is lit: the mesh of gear index + 1 is aligned.
    public static func isPipLit(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> Bool {
        let gear: Int = index + 1
        guard gear >= 1, gear < snapshot.report.errors.count else { return false }
        return snapshot.isAligned(gear)
    }

    /// The width of one moves slot, 1.8 / budget.
    public static func movesSlot(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        (movesEnd - movesStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of moves bar `index`: (−0.9 + (index + 0.5) · slot, −0.40, −0.6).
    public static func movesBar(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        SIMD3(movesStart + (Double(index) + 0.5) * movesSlot(snapshot), movesY, gaugeZ)
    }

    /// The moves bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litMoves(_ snapshot: MoonlitMechanismSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The won flag: 1 when the level is won (stage won, or result without a failure), else 0. A won level brightens
    /// the paper; no position changes.
    public static func wonFlag(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil) ? 1 : 0
    }

    /// The gears in painter's order: ascending plane (depth), then index.
    public static func gearOrder(_ snapshot: MoonlitMechanismSceneSnapshot) -> [Int] {
        Array(snapshot.gears.indices).sorted { a, b in
            let da: Int = snapshot.gears[a].depth
            let db: Int = snapshot.gears[b].depth
            return da != db ? da < db : a < b
        }
    }

    /// The unit direction (x, y) of gear `index`'s slot `slot` spoke: the mean of the slot's offsets (column right, row
    /// down, so y = −row); for offsets averaging to nothing, the slot's angle π/2 − slot · 2π / T.
    public static func spokeDirection(_ index: Int, slot: Int,
                                      _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD2<Double> {
        guard !snapshot.gears.isEmpty else { return SIMD2(0, 1) }
        let gear: MoonlitMechanismGear = snapshot.gears[clamped(index, snapshot.gears.count)]
        let teeth: Int = max(gear.teeth, 1)
        var sum: SIMD2<Double> = SIMD2(0, 0)
        if slot >= 0, slot < gear.slots.count {
            for offset in gear.slots[slot] { sum += SIMD2(Double(offset.column), -Double(offset.row)) }
        }
        let length: Double = (sum.x * sum.x + sum.y * sum.y).squareRoot()
        if length > 1e-9 { return sum / length }
        let a: Double = Double.pi / 2 - Double(slot) * 2 * Double.pi / Double(teeth)
        return SIMD2(cos(a), sin(a))
    }

    /// The child and parent of a `jammed` failure's pair, or nil.
    public static func jammedPair(_ snapshot: MoonlitMechanismSceneSnapshot) -> (child: Int, parent: Int)? {
        guard case .jammed(let child)? = snapshot.failure, child >= 0, child < snapshot.gears.count,
              let parent = snapshot.gears[child].parent else { return nil }
        return (child: child, parent: parent)
    }

    /// The cell a `forbidden` failure names, or nil.
    public static func brokenCell(_ snapshot: MoonlitMechanismSceneSnapshot) -> Int? {
        guard case .forbidden(_, let cell)? = snapshot.failure else { return nil }
        return cell
    }

    /// The key frame whose card a `missing` or `stray` failure names, or nil.
    public static func failingCard(_ snapshot: MoonlitMechanismSceneSnapshot) -> Int? {
        switch snapshot.failure {
        case .missing(let frame, _)?, .stray(let frame, _)?:
            return frame >= 0 && frame < snapshot.keyFrames.count ? frame : nil
        default:
            return nil
        }
    }

    /// `a` mixed towards `b` by `t`.
    static func mix(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ t: Double) -> SIMD3<Double> { a + (b - a) * t }

    /// The fallback colour of `material` (unlit): the palette colour; the translucent gear body and blades
    /// pre-mixed over the paper by ``MoonlitMechanismPalette/gearAlpha`` and ``MoonlitMechanismPalette/bladeAlpha``,
    /// the feather halfway from ink to paper, the notch halfway from rim to ink, the ladder and the card border in the
    /// rim gold, the dotted missing cells in the target blue.
    public static func colour(_ material: Material) -> SIMD3<Double> {
        typealias P = MoonlitMechanismPalette
        switch material {
        case .backdrop: return P.night
        case .paper: return P.paper
        case .ink: return P.ink
        case .inkFeather: return mix(P.ink, P.paper, 0.5)
        case .targetOutline: return P.target
        case .missingDotted: return P.target
        case .strayHatch: return P.stray
        case .forbiddenMark: return P.forbidden
        case .gearBody: return mix(P.paper, P.gear, P.gearAlpha)
        case .gearRim: return P.rim
        case .gearNotch: return mix(P.rim, P.ink, 0.5)
        case .blade: return mix(P.paper, P.blade, P.bladeAlpha)
        case .lamp: return P.lamp
        case .ladder: return P.rim
        case .cardLit: return P.cardLit
        case .cardUnlit: return P.cardUnlit
        case .cardBorder: return P.rim
        case .alignLit: return P.alignLit
        case .alignUnlit: return P.alignUnlit
        case .movesLit: return P.movesLit
        case .movesUnlit: return P.movesUnlit
        case .broken: return P.broken
        }
    }

    /// The paper's fallback colour: lifted towards white by ``wonLift`` · `won`.
    public static func paperColour(won: Double) -> SIMD3<Double> {
        mix(MoonlitMechanismPalette.paper, SIMD3(1, 1, 1), wonLift * min(max(won, 0), 1))
    }

    /// The share 0 … 1 of a tooth's height at position `u` (−0.5 … 0.5) of its period: 1 within ±1/6, 0 beyond
    /// ±1/3, linear between.
    public static func toothProfile(_ u: Double) -> Double {
        let a: Double = abs(u)
        if a <= toothTop { return 1 }
        if a >= toothBase { return 0 }
        return (toothBase - a) / (toothBase - toothTop)
    }

    // MARK: Meshes

    /// The clockwork mesh for the clockwork program, in painter's order (see the header), at the drawn phases.
    public static func clockworkMesh(_ snapshot: MoonlitMechanismSceneSnapshot, tier: MoonlitMechanismTier,
                                     reduceMotion: Bool) throws(MeshError) -> Mesh {
        try clockworkPart(snapshot, tier: tier, reduceMotion: reduceMotion).mesh
    }

    /// The glow mesh for the glow program (`glowPart` without colours); empty at level-2.
    public static func glowMesh(_ snapshot: MoonlitMechanismSceneSnapshot,
                                tier: MoonlitMechanismTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    /// The clockwork with fallback colours (unlit palette colours, ``colour(_:)``; the paper lifted on a won level)
    /// for the shared unlit renderer: the same mesh as ``clockworkMesh(_:tier:reduceMotion:)``.
    public static func clockworkPart(_ snapshot: MoonlitMechanismSceneSnapshot, tier: MoonlitMechanismTier,
                                     reduceMotion: Bool = false) throws(MeshError) -> MoonlitMechanismColouredMesh {
        var parts: Parts = Parts()
        let s: Double = cellSize(snapshot)
        let won: Double = wonFlag(snapshot)
        let phases: [Int] = drawnPhases(snapshot, reduceMotion: reduceMotion)
        // 1. Backdrop.
        try parts.quad([SIMD3(backdropX.lowerBound, backdropY.lowerBound, backdropZ),
                        SIMD3(backdropX.upperBound, backdropY.lowerBound, backdropZ),
                        SIMD3(backdropX.upperBound, backdropY.upperBound, backdropZ),
                        SIMD3(backdropX.lowerBound, backdropY.upperBound, backdropZ)],
                       material: .backdrop, local: [0, 0, 0, 0])
        // 2. Paper.
        let halfW: Double = Double(snapshot.width) * s / 2
        let halfH: Double = Double(snapshot.rows) * s / 2
        try parts.quad([SIMD3(-halfW, wallCentreY - halfH, wallZ), SIMD3(halfW, wallCentreY - halfH, wallZ),
                        SIMD3(halfW, wallCentreY + halfH, wallZ), SIMD3(-halfW, wallCentreY + halfH, wallZ)],
                       material: .paper, local: [0, 0, 0, 0], colour: paperColour(won: won))
        // 3. Feathers, 4. ink squares.
        let inkHalf: Double = inkSide * s / 2
        if tier.softEdge {
            for cell in snapshot.cast {
                try parts.frame(centre: cellCentre(cell, snapshot), inner: SIMD2(inkHalf, inkHalf),
                                outer: SIMD2(inkHalf + featherWidth * s, inkHalf + featherWidth * s),
                                material: .inkFeather, local: (0, 1))
            }
        }
        for cell in snapshot.cast {
            try parts.rectangle(centre: cellCentre(cell, snapshot), half: SIMD2(inkHalf, inkHalf), material: .ink)
        }
        // 5. Target borders.
        let cellHalf: Double = s / 2
        for cell in snapshot.target {
            try parts.frame(centre: cellCentre(cell, snapshot),
                            inner: SIMD2(cellHalf - targetLine * s, cellHalf - targetLine * s),
                            outer: SIMD2(cellHalf, cellHalf), material: .targetOutline, local: (-1, 1))
        }
        // 6. Missing cells dotted (an outline band the shader dots).
        for cell in snapshot.missingCells {
            try parts.frame(centre: cellCentre(cell, snapshot),
                            inner: SIMD2(missingBand.lowerBound * s, missingBand.lowerBound * s),
                            outer: SIMD2(missingBand.upperBound * s, missingBand.upperBound * s),
                            material: .missingDotted, local: (-1, 1))
        }
        // 7. Stray cells hatched (a square the shader hatches).
        for cell in snapshot.strayCells {
            try parts.rectangle(centre: cellCentre(cell, snapshot), half: SIMD2(inkHalf, inkHalf),
                                material: .strayHatch)
        }
        // 8. Forbidden crosses and a forbidden failure's outline.
        let crossHalf: Double = cellHalf - crossInset * s
        for cell in snapshot.forbidden {
            let c: SIMD3<Double> = cellCentre(cell, snapshot)
            try parts.strip(c + SIMD3(-crossHalf, -crossHalf, 0), c + SIMD3(crossHalf, crossHalf, 0),
                            width: crossWidth * s, material: .forbiddenMark)
            try parts.strip(c + SIMD3(-crossHalf, crossHalf, 0), c + SIMD3(crossHalf, -crossHalf, 0),
                            width: crossWidth * s, material: .forbiddenMark)
        }
        if let cell = brokenCell(snapshot) {
            let inner: Double = cellHalf + cellOutline.lowerBound * s
            let outer: Double = cellHalf + cellOutline.upperBound * s
            try parts.frame(centre: cellCentre(cell, snapshot), inner: SIMD2(inner, inner), outer: SIMD2(outer, outer),
                            material: .broken, local: (-1, 1))
        }
        // 9. Gauges: cards, pips, moves bars.
        let cardHalf: SIMD2<Double> = SIMD2(cardWidth(snapshot) / 2, cardHeight / 2)
        let failing: Int? = failingCard(snapshot)
        for index in snapshot.keyFrames.indices {
            let c: SIMD3<Double> = card(index, snapshot)
            try parts.rectangle(centre: c, half: cardHalf, material: .cardUnlit)
            let f: Double = cardFraction(index, snapshot)
            if f > 0 {
                let w: Double = 2 * cardHalf.x * f
                try parts.rectangle(centre: c + SIMD3(-cardHalf.x + w / 2, 0, 0), half: SIMD2(w / 2, cardHalf.y),
                                    material: .cardLit)
            }
            if snapshot.keyFrames[index].required {
                try parts.frame(centre: c, inner: cardHalf - SIMD2(borderLine, borderLine), outer: cardHalf,
                                material: .cardBorder, local: (-1, 1))
            }
            if failing == index {
                try parts.frame(centre: c, inner: cardHalf + SIMD2(cardOutline.lowerBound, cardOutline.lowerBound),
                                outer: cardHalf + SIMD2(cardOutline.upperBound, cardOutline.upperBound),
                                material: .broken, local: (-1, 1))
            }
        }
        let pip: Double = pipSide(snapshot) / 2
        for index in 0..<pipCount(snapshot) {
            if isPipLit(index, snapshot) {
                try parts.rectangle(centre: alignmentPip(index, snapshot), half: SIMD2(pip, pip), material: .alignLit)
            } else {
                let inner: Double = pip * (1 - 2 * pipLine)
                try parts.frame(centre: alignmentPip(index, snapshot), inner: SIMD2(inner, inner),
                                outer: SIMD2(pip, pip), material: .alignUnlit, local: (-1, 1))
            }
        }
        let lit: Int = litMoves(snapshot)
        let barHalf: SIMD2<Double> = SIMD2(barFill * movesSlot(snapshot) / 2, barHeight / 2)
        for index in 0..<max(snapshot.budget, 0) {
            try parts.rectangle(centre: movesBar(index, snapshot), half: barHalf,
                                material: index < lit ? .movesLit : .movesUnlit)
        }
        // 10. Gears, back to front, then a jammed pair's outline.
        let radius: Double = rimRadius * s
        let tooth: Double = toothHeight * s
        let segments: Int = max(tier.segmentsPerTooth, 1)
        for index in gearOrder(snapshot) {
            let gear: MoonlitMechanismGear = snapshot.gears[index]
            let teeth: Int = max(gear.teeth, 1)
            let c: SIMD3<Double> = gearCentre(index, snapshot)
            let rimInner: Double = radius - rimBand * s
            let count: Int = teeth * segments
            var body: [SIMD3<Double>] = []
            for j in 0..<count {
                let a: Double = toothAngle(index, tooth: Double(j) / Double(segments) - 0.5, snapshot)
                body.append(c + SIMD3(cos(a), sin(a), 0) * rimInner)
            }
            try parts.fan(centre: c, outline: body, material: .gearBody)
            for j in 0..<count {
                let u0: Double = Double(j) / Double(segments)
                let u1: Double = Double(j + 1) / Double(segments)
                let p0: Double = u0 - u0.rounded(.down) - 0.5
                let p1: Double = u1 - (u1 - 1e-9).rounded(.down) - 0.5
                let a0: Double = toothAngle(index, tooth: u0 - 0.5, snapshot)
                let a1: Double = toothAngle(index, tooth: u1 - 0.5, snapshot)
                try parts.band(centre: c, inner: (rimInner, rimInner),
                               outer: (radius + tooth * toothProfile(p0), radius + tooth * toothProfile(p1)),
                               angles: (a0, a1), material: .gearRim)
            }
            let notch: Double = toothAngle(index, tooth: 0, snapshot)
            let nd: SIMD3<Double> = SIMD3(cos(notch), sin(notch), 0)
            try parts.strip(c + nd * rimInner, c + nd * (radius + notchReach * tooth), width: notchWidth * s,
                            material: .gearNotch)
            let phase: Int = index < phases.count ? phases[index] : 0
            for bit in 0..<min(teeth, gear.blades.count) where gear.blades[bit] {
                let slot: Int = MoonlitMechanismTrain.mod(bit + phase, teeth)
                let d2: SIMD2<Double> = spokeDirection(index, slot: slot, snapshot)
                let d: SIMD3<Double> = SIMD3(d2.x, d2.y, 0)
                try parts.strip(c + d * (hubRadius * s), c + d * (bodyInner * radius), width: spokeWidth * s,
                                material: .blade)
            }
        }
        if let pair = jammedPair(snapshot) {
            for (a, b) in [(pair.child, pair.parent), (pair.parent, pair.child)] {
                let ca: SIMD3<Double> = gearCentre(a, snapshot)
                let cb: SIMD3<Double> = gearCentre(b, snapshot)
                let dx: Double = cb.x - ca.x
                let dy: Double = cb.y - ca.y
                let towards: Double = dx == 0 && dy == 0 ? 0 : atan2(dy, dx)
                let half: Double = jamSpan * 2 * Double.pi / Double(max(snapshot.gears[a].teeth, 1))
                let inner: Double = radius + tooth + jamBand.lowerBound * s
                let outer: Double = radius + tooth + jamBand.upperBound * s
                for k in 0..<jamSegments {
                    let a0: Double = towards - half + 2 * half * Double(k) / Double(jamSegments)
                    let a1: Double = towards - half + 2 * half * Double(k + 1) / Double(jamSegments)
                    try parts.band(centre: ca, inner: (inner, inner), outer: (outer, outer), angles: (a0, a1),
                                   material: .broken)
                }
            }
        }
        // 11. Ladder and lamp.
        let rungs: Int = max(snapshot.lampHeights, 1)
        let top: Double = lampBaseY + lampStep * Double(rungs - 1)
        for side in [-1.0, 1.0] {
            let x: Double = ladderX + side * rungWidth / 2
            try parts.strip(SIMD3(x, lampBaseY - rungLine, lampZ), SIMD3(x, top + rungLine, lampZ), width: railWidth,
                            material: .ladder)
        }
        for k in 0..<rungs {
            let y: Double = lampBaseY + lampStep * Double(k)
            try parts.strip(SIMD3(ladderX - rungWidth / 2, y, lampZ), SIMD3(ladderX + rungWidth / 2, y, lampZ),
                            width: rungLine, material: .ladder)
        }
        try parts.disc(centre: lampCentre(snapshot), radius: lampRadius, segments: lampSegments, material: .lamp)
        return parts.built()
    }

    /// The lamp's centre: (0, 1.30 + 0.03 · height, 0.35).
    public static func lampCentre(_ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double> {
        SIMD3(lampX, lampBaseY + lampStep * Double(snapshot.height), lampZ)
    }

    /// The glow kind of a glow vertex: a_uv.x = 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable {
        /// A shell around the lamp.
        case lamp = 0
        /// A shell around a lit card.
        case card = 1
        /// A shell around the paper wall of a won level.
        case wall = 2

        /// The a_uv.x code 2 · kind + factor (factor clamped to 0 … 1).
        public func code(factor: Double) -> Double { 2 * Double(rawValue) + min(max(factor, 0), 1) }
    }

    /// The glow with fallback colours (the base colour times the factor) for the shared unlit renderer:
    /// `tier.glowShells` shells k (outermost first), each a band from the object's edge (a_uv.y 0) to its edge grown
    /// by k growths (a_uv.y 1): around the lamp (``lampGlowGrowth``, factor 0.5^k, colour
    /// ``MoonlitMechanismPalette/lampGlow``), around every card with a covered fraction f above 0 (``cardGlowGrowth``,
    /// factor 0.5^k · f, colour ``MoonlitMechanismPalette/glow``) and, on a won level only, around the paper wall
    /// (``wallGlowGrowth``, factor 0.5^k, colour ``MoonlitMechanismPalette/glow``); each lifted 0.001 · k towards the
    /// viewer. a_normal is the colour, a_uv.x = ``GlowKind/code(factor:)``. Empty at level-2.
    public static func glowPart(_ snapshot: MoonlitMechanismSceneSnapshot,
                                tier: MoonlitMechanismTier) throws(MeshError) -> MoonlitMechanismColouredMesh {
        var parts: Parts = Parts()
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let lampGlow: SIMD3<Double> = MoonlitMechanismPalette.lampGlow
        let glow: SIMD3<Double> = MoonlitMechanismPalette.glow
        let cardHalf: SIMD2<Double> = SIMD2(cardWidth(snapshot) / 2, cardHeight / 2)
        let s: Double = cellSize(snapshot)
        let wallHalf: SIMD2<Double> = SIMD2(Double(snapshot.width) * s / 2, Double(snapshot.rows) * s / 2)
        let won: Bool = wonFlag(snapshot) == 1
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            let lift: SIMD3<Double> = SIMD3(0, 0, glowLift * Double(k))
            if won {
                let grow: Double = wallGlowGrowth * Double(k)
                try parts.glowFrame(centre: SIMD3(0, wallCentreY, wallZ) + lift, inner: wallHalf,
                                    outer: wallHalf + SIMD2(grow, grow), slot: glow,
                                    code: GlowKind.wall.code(factor: factor), colour: glow * factor)
            }
            for index in snapshot.keyFrames.indices {
                let f: Double = cardFraction(index, snapshot)
                guard f > 0 else { continue }
                let grow: Double = cardGlowGrowth * Double(k)
                try parts.glowFrame(centre: card(index, snapshot) + lift, inner: cardHalf,
                                    outer: cardHalf + SIMD2(grow, grow), slot: glow,
                                    code: GlowKind.card.code(factor: factor * f), colour: glow * (factor * f))
            }
            try parts.glowRing(centre: lampCentre(snapshot) + lift, inner: lampRadius,
                               outer: lampRadius + lampGlowGrowth * Double(k), slot: lampGlow,
                               code: GlowKind.lamp.code(factor: factor), colour: lampGlow * factor)
        }
        return parts.built()
    }

    // MARK: Camera

    /// `aspect` made usable: 1 when not finite and positive, else clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// Corner `index` (0 … 7; bit 0 x, bit 1 y, bit 2 z, clear: low) of the authored box.
    static func corner(_ index: Int) -> SIMD3<Double> {
        SIMD3(index & 1 == 0 ? boxLow.x : boxHigh.x, index & 2 == 0 ? boxLow.y : boxHigh.y,
              index & 4 == 0 ? boxLow.z : boxHigh.z)
    }

    /// The dot product of `a` and `b`.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    /// The cross product a × b.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// `v` scaled to unit length (unchanged when zero).
    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let l: Double = dot(v, v).squareRoot()
        return l > 0 ? v / l : v
    }

    /// The fixed camera for `aspect`: from (0, 0.65, 2.4) looking at (0, 0.55, −0.3) with +y up; the vertical field of
    /// view is the smallest that holds every corner of the box x −0.95 … 0.95, y −0.45 … 1.5, z −0.6 … 0.4 inside the
    /// view with ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it — every
    /// cell, gear, the lamp, card, pip and bar of a catalog level — keeps a margin of at least 5 % for aspect
    /// 0.4 … 2.5). The snapshot is accepted for parity.
    public static func camera(_ snapshot: MoonlitMechanismSceneSnapshot, aspect: Double) -> MoonlitMechanismCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
        let forward: SIMD3<Double> = unit(lookAt - eye)
        let right: SIMD3<Double> = unit(cross(forward, SIMD3(0, 1, 0)))
        let up: SIMD3<Double> = cross(right, forward)
        let limit: Double = 1 - 2 * fitMargin
        var tanHalf: Double = 0
        var nearest: Double = Double.infinity
        var farthest: Double = 0
        for index in 0..<8 {
            let r: SIMD3<Double> = corner(index) - eye
            let depth: Double = dot(r, forward)
            nearest = min(nearest, depth)
            farthest = max(farthest, depth)
            tanHalf = max(tanHalf, abs(dot(r, up)) / depth / limit, abs(dot(r, right)) / depth / (a * limit))
        }
        let fovY: Double = 2 * atan(tanHalf)
        let near: Double = max(nearest * 0.5, 1e-3)
        let far: Double = farthest + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(lookAt), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return MoonlitMechanismCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far, view: view,
                                      projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: MoonlitMechanismCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from +z.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []

        /// Adds (or welds) a vertex at `p` with normal slot `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour`.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(MoonlitMechanismSceneGeometry.vec(p),
                                                normal: MoonlitMechanismSceneGeometry.vec(slot), uv: Vec2(code, local))
            if Int(id) == colours.count {
                colours.append(Vec4(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from +z; degenerate triangles are skipped.
        mutating func facing(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>) throws(MeshError) {
            let side: Double = (pb.x - pa.x) * (pc.y - pa.y) - (pb.y - pa.y) * (pc.x - pa.x)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A convex quad (corners in order) with local coordinates `local`, uv.x the material's code (or `code`),
        /// normal slot `slot` (default (0, 0, 1)), in `colour` (default the material's colour).
        mutating func quad(_ p: [SIMD3<Double>], material: Material, local: [Double], colour: SIMD3<Double>? = nil,
                           code: Double? = nil, slot: SIMD3<Double> = SIMD3(0, 0, 1)) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? MoonlitMechanismSceneGeometry.colour(material)
            let value: Double = code ?? Double(material.rawValue)
            var ids: [UInt32] = []
            for k in 0..<4 { ids.append(try vertex(p[k], slot: slot, code: value, local: local[k], colour: tint)) }
            try facing((ids[0], ids[1], ids[2]), p[0], p[1], p[2])
            try facing((ids[0], ids[2], ids[3]), p[0], p[2], p[3])
        }

        /// A fan through the convex `outline` around `centre`: local 0 at the centre and 1 on the outline.
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], material: Material,
                          colour: SIMD3<Double>? = nil, code: Double? = nil,
                          slot: SIMD3<Double> = SIMD3(0, 0, 1)) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? MoonlitMechanismSceneGeometry.colour(material)
            let value: Double = code ?? Double(material.rawValue)
            let c: UInt32 = try vertex(centre, slot: slot, code: value, local: 0, colour: tint)
            var ids: [UInt32] = []
            for p in outline { ids.append(try vertex(p, slot: slot, code: value, local: 1, colour: tint)) }
            for k in outline.indices {
                let j: Int = (k + 1) % outline.count
                try facing((c, ids[k], ids[j]), centre, outline[k], outline[j])
            }
        }

        /// An axis-aligned rectangle of half size `half` around `centre`, as a fan.
        mutating func rectangle(centre: SIMD3<Double>, half: SIMD2<Double>, material: Material) throws(MeshError) {
            try fan(centre: centre, outline: Self.corners(centre, half), material: material)
        }

        /// The four corners of the axis-aligned rectangle of half size `half` around `centre`, anticlockwise.
        static func corners(_ centre: SIMD3<Double>, _ half: SIMD2<Double>) -> [SIMD3<Double>] {
            [centre + SIMD3(-half.x, -half.y, 0), centre + SIMD3(half.x, -half.y, 0), centre + SIMD3(half.x, half.y, 0),
             centre + SIMD3(-half.x, half.y, 0)]
        }

        /// A rectangular frame between the half sizes `inner` and `outer` around `centre`, four quads with local
        /// `local.0` on the inner edge and `local.1` on the outer edge.
        mutating func frame(centre: SIMD3<Double>, inner: SIMD2<Double>, outer: SIMD2<Double>, material: Material,
                            local: (Double, Double)) throws(MeshError) {
            let i: [SIMD3<Double>] = Self.corners(centre, SIMD2(max(inner.x, 0), max(inner.y, 0)))
            let o: [SIMD3<Double>] = Self.corners(centre, outer)
            for k in 0..<4 {
                let j: Int = (k + 1) % 4
                try quad([i[k], o[k], o[j], i[j]], material: material, local: [local.0, local.1, local.1, local.0])
            }
        }

        /// A straight strip of `width` from `a` to `b` (one quad, local −1 on the left edge and +1 on the right).
        mutating func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double,
                            material: Material) throws(MeshError) {
            let dx: Double = b.x - a.x
            let dy: Double = b.y - a.y
            let length: Double = (dx * dx + dy * dy).squareRoot()
            guard length > 0 else { return }
            let n: SIMD3<Double> = SIMD3(-dy / length, dx / length, 0) * (width / 2)
            try quad([a + n, b + n, b - n, a - n], material: material, local: [-1, -1, 1, 1])
        }

        /// One segment of a band around `centre` from angle `angles.0` to `angles.1`, radii `inner` and `outer` at
        /// the two angles (local −1 inside, +1 outside).
        mutating func band(centre: SIMD3<Double>, inner: (Double, Double), outer: (Double, Double),
                           angles: (Double, Double), material: Material) throws(MeshError) {
            let d0: SIMD3<Double> = SIMD3(cos(angles.0), sin(angles.0), 0)
            let d1: SIMD3<Double> = SIMD3(cos(angles.1), sin(angles.1), 0)
            try quad([centre + d0 * inner.0, centre + d0 * outer.0, centre + d1 * outer.1, centre + d1 * inner.1],
                     material: material, local: [-1, 1, 1, -1])
        }

        /// A disc of `radius` around `centre` in `segments`, as a fan.
        mutating func disc(centre: SIMD3<Double>, radius: Double, segments: Int, material: Material) throws(MeshError) {
            try fan(centre: centre, outline: Self.circle(centre, radius, segments), material: material)
        }

        /// The `segments` points of the circle of `radius` around `centre`, anticlockwise from +x.
        static func circle(_ centre: SIMD3<Double>, _ radius: Double, _ segments: Int) -> [SIMD3<Double>] {
            var points: [SIMD3<Double>] = []
            let count: Int = max(segments, 3)
            for i in 0..<count {
                let a: Double = 2 * Double.pi * Double(i) / Double(count)
                points.append(centre + SIMD3(cos(a), sin(a), 0) * radius)
            }
            return points
        }

        /// A glow ring around `centre` from radius `inner` (a_uv.y 0) to `outer` (a_uv.y 1): normal slot `slot` (the
        /// colour), a_uv.x `code`, fallback colour `colour`.
        mutating func glowRing(centre: SIMD3<Double>, inner: Double, outer: Double, slot: SIMD3<Double>, code: Double,
                               colour: SIMD3<Double>) throws(MeshError) {
            let i: [SIMD3<Double>] = Self.circle(centre, inner, MoonlitMechanismSceneGeometry.lampSegments)
            let o: [SIMD3<Double>] = Self.circle(centre, outer, MoonlitMechanismSceneGeometry.lampSegments)
            for k in i.indices {
                let j: Int = (k + 1) % i.count
                try quad([i[k], o[k], o[j], i[j]], material: .lamp, local: [0, 1, 1, 0], colour: colour, code: code,
                         slot: slot)
            }
        }

        /// A glow frame around `centre` between the half sizes `inner` (a_uv.y 0) and `outer` (a_uv.y 1): normal slot
        /// `slot` (the colour), a_uv.x `code`, fallback colour `colour`.
        mutating func glowFrame(centre: SIMD3<Double>, inner: SIMD2<Double>, outer: SIMD2<Double>, slot: SIMD3<Double>,
                                code: Double, colour: SIMD3<Double>) throws(MeshError) {
            let i: [SIMD3<Double>] = Self.corners(centre, inner)
            let o: [SIMD3<Double>] = Self.corners(centre, outer)
            for k in 0..<4 {
                let j: Int = (k + 1) % 4
                try quad([i[k], o[k], o[j], i[j]], material: .cardLit, local: [0, 1, 1, 0], colour: colour, code: code,
                         slot: slot)
            }
        }

        /// The coloured mesh built so far.
        func built() -> MoonlitMechanismColouredMesh {
            MoonlitMechanismColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
