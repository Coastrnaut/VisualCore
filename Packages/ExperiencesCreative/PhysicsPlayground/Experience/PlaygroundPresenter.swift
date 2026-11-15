// PlaygroundPresenter — feature 082 (A11-P01) T-A11-104 (FR-A11-120, FR-A11-121; clarification 5). Draws Physics
// Playground through the host only (the host's context and registry, VisualCore's `PrimitiveRenderer` with a
// `Camera2D`; no context of its own). The scene is code, rebuilt every frame from the core's world, which the presenter
// only reads:
//   - Mapping: the view is the 10 × 8 m stage plus its 1 m walls on every side (12 × 10 m, y up, centred on the stage
//     centre (5, 4) m), scaled uniformly to fit the canvas and centred; the canvas is cleared in a near-black letterbox
//     colour and four letterbox masks above everything else hide whatever lies outside the view. The simulation never
//     sees the canvas.
//   - Stage: one dark rect (the stage background) and the four walls of `WorldSimulation.walls(for:)` as grey rects.
//   - Bodies at their physics size in their material colours: a circle is a filled circle of its radius, a closed ring
//     (33 points) of its radius in the edge colour and a radius line from the centre at the body's angle, so rotation
//     shows; a box is a filled polygon of its four rotated corners with a closed outline in the edge colour. A static
//     body is drawn darker (fill × 0.55, edge × 0.7) with a hatch inside its shape (parallel lines across it, joined
//     at its edge into one path). A body whose material is not in the catalog is drawn in a neutral grey.
// There is no decorative motion, so Reduce Motion changes nothing; nothing flashes. No audio.
//
// Feature 083 (A11-P02) T-A11-204 (FR-A11-220, FR-A11-221; clarification 5): every spring is drawn under the bodies
// (so the bodies stay readable and a body's centre still shows its fill) as an 8-coil zigzag polyline 0.03 m wide
// between its two world anchors at its current length — a body anchor through the body's pose
// (`PhysicsWorld.anchorPosition`), a world anchor fixed — with straight leads of 10 % of the length at each end and
// coils 0.12 m to each side of the axis, plus a small dot (radius 0.06 m) at each anchor, in a pale spring colour. The
// description adds the springs, the stiffness level, gravity and drag ("2 springs, stiffness medium, gravity Earth,
// drag low"), and the frame probe also steps aside when a spring passes near it.
//
// Feature 084 (A11-P03) T-A11-303 (FR-A11-303, FR-A11-310, FR-A11-311; SC-A11-301, SC-A11-304; clarifications 2, 4;
// research D4): canvas pointer events go through `PlaygroundGestures` (tap, double tap, long press and drag over
// VisualCore's arbiter; `gestureActions` are its seven edit actions, each also sent by a native control), with the
// shape picker's kind kept here as presentation state; a held tap or a long press held still is resolved on the frame
// tick (`advance(by:)` with the frame's delta); the gesture state is reset on suspension and teardown. Overlays, drawn
// from the world and the core's measured forces (`PlaygroundCore.forces`) and never writing either, above the bodies:
//   - velocity arrows (when `showVelocity`): from each non-static body's centre along v, 0.25 s × |v| m long, capped at
//     2 m, in a pale cyan;
//   - force arrows (when `showForces`): each non-static body's weight m·g (`ForceMeasurement.weight`) in orange and
//     its measured net spring force (`ForceMeasurement.springForce`, only while the measurement belongs to the drawn
//     tick) in green, each 0.05 m per newton, capped at 2 m;
//   - every arrow is a shaft 0.04 m wide (at least a pixel) and a triangular head 0.12 m long and 0.12 m wide whose
//     tip is the arrow's end (a shorter arrow is all head); a zero vector draws nothing;
//   - the grab line, 0.02 m wide (at least a pixel), from the grabbed body's anchor to the grab's target;
//   - a ring around the selected body (its bounding radius + 0.1 m) and a small dot (radius 0.08 m) at the centre of
//     every pinned body.
// The description adds the pinned bodies, the selection, a grab and the overlays ("none pinned, no selection, arrows
// off"), the mirror carries the state panel (`PlaygroundPanel`: kinetic, potential, spring and total energy, momentum
// and the selected body's speed from `WorldDiagnostics`), and the probe steps aside for every overlay near it.
import Foundation
import SwiftUI
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class PlaygroundMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The number of bodies, static ones included.
    var bodyCount = 0
    /// Whether the world is paused.
    var paused = false
    /// The time-scale index, 0…3 (¼, ½, 1, 2).
    var timeScaleIndex = PhysicsWorld.normalTimeScaleIndex
    /// The gravity level, 0…2 (off, Moon, Earth).
    var gravityLevel = ForceLevels.defaultGravityLevel
    /// The drag level, 0…2 (none, low, high).
    var dragLevel = ForceLevels.defaultDragLevel
    /// The stiffness level, 0…3 (soft, medium, stiff, very stiff).
    var stiffnessLevel = ForceLevels.defaultStiffnessLevel
    /// The status line: bodies, running or paused, time scale.
    var status = ""
    /// The forces line: springs, stiffness, gravity and drag.
    var forces = ""
    /// The body ids in drawing order (the previous and next selection controls walk them; feature 084).
    var bodyIds: [Int] = []
    /// The selected body's id, nil without a selection.
    var selectedId: Int?
    /// The selected body's centre in stage metres (the native hold grabs there).
    var selectedCenter: Vec2?
    /// Whether the selected body is static.
    var selectedStatic = false
    /// Whether the selected body is pinned.
    var selectedPinned = false
    /// The grabbed body's id, nil without a grab.
    var grabbedId: Int?
    /// The grab's target in stage metres, nil without a grab.
    var grabTarget: Vec2?
    /// The number of pinned bodies.
    var pinnedCount = 0
    /// Whether velocity arrows are drawn.
    var showVelocity = false
    /// Whether force arrows are drawn.
    var showForces = false
    /// The shape picker's kind, 0 circle or 1 box (presentation state, never in the world): what a tap on the empty
    /// stage and "Add at centre" add.
    var shapeKind = BodyKind.circle.rawValue
    /// The state panel's measured values.
    var panel = PlaygroundPanel()
    /// The editing line: pinned bodies, the selection, a grab and the overlays.
    var editing = ""
}

/// The measured values of the state panel (feature 084, FR-A11-311): read from `WorldDiagnostics` without changing the
/// world, shown with two decimals.
struct PlaygroundPanel: Equatable, Sendable {
    /// Kinetic energy in joules.
    var kinetic = 0.0
    /// Gravitational potential energy above the floor in joules.
    var potential = 0.0
    /// Spring potential energy in joules.
    var spring = 0.0
    /// Total energy in joules.
    var total = 0.0
    /// The magnitude of the total momentum in kg·m/s.
    var momentum = 0.0
    /// The selected body's speed in m/s; nil without a selection.
    var speed: Double?

    /// The panel of `world`: `WorldDiagnostics`' energies, the magnitude of its momentum and the selected body's speed.
    static func measure(_ world: PhysicsWorld, catalog: MaterialCatalog = PlaygroundCore.catalog) -> PlaygroundPanel {
        var panel = PlaygroundPanel()
        panel.kinetic = WorldDiagnostics.kineticEnergy(world, catalog: catalog)
        panel.potential = WorldDiagnostics.potentialEnergy(world, catalog: catalog)
        panel.spring = WorldDiagnostics.springPotentialEnergy(world, catalog: catalog)
        panel.total = WorldDiagnostics.totalEnergy(world, catalog: catalog)
        panel.momentum = WorldDiagnostics.momentum(world, catalog: catalog).length
        if let id = world.selectedId, let index = world.index(ofBody: id) {
            panel.speed = world.bodies[index].velocity.length
        }
        return panel
    }

    /// `value` with two decimals ("1.25"; never "-0.00"; "—" for a non-finite value).
    static func text(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let rounded = (value * 100).rounded() / 100
        return String(format: "%.2f", rounded == 0 ? 0 : rounded)
    }

    /// The note above the values.
    static let note = "Educational approximation"
    /// What the force arrows leave out.
    static let arrowNote =
        "Arrows show velocity, weight and the net spring force; contact and drag forces are not drawn."

    /// The panel's rows: (identifier name, label, value with its unit).
    var rows: [(name: String, label: String, value: String)] {
        [("panel-kinetic", "Kinetic energy", Self.text(kinetic) + " J"),
         ("panel-potential", "Potential energy", Self.text(potential) + " J"),
         ("panel-spring", "Spring energy", Self.text(spring) + " J"),
         ("panel-total", "Total energy", Self.text(total) + " J"),
         ("panel-momentum", "Momentum", Self.text(momentum) + " kg·m/s"),
         ("panel-speed", "Selected speed", speed.map { Self.text($0) + " m/s" } ?? "no selection")]
    }
}

/// One overlay arrow in stage metres: from its start to its tip.
struct PlaygroundArrow: Equatable, Sendable {
    /// What the arrow shows.
    enum Kind: Int, CaseIterable, Sendable {
        /// The body's velocity.
        case velocity
        /// The body's weight.
        case weight
        /// The net spring force on the body.
        case spring
    }

    /// The arrow's start (the body's centre) in metres.
    var from: Vec2
    /// The arrow's tip in metres.
    var to: Vec2

    /// The arrow's length in metres.
    var length: Double { (to - from).length }
    /// The arrow's unit direction.
    var direction: Vec2 { (to - from) / length }

    /// The arrow from `from` along `vector`, `scale` metres per unit of the vector and capped at `maxLength` metres;
    /// nil for a zero or non-finite vector.
    static func make(from: Vec2, vector: Vec2, scale: Double, maxLength: Double) -> PlaygroundArrow? {
        let magnitude = vector.length, length = magnitude * scale
        guard from.isFinite, vector.isFinite, length.isFinite, length > 0, magnitude > 0 else { return nil }
        return PlaygroundArrow(from: from, to: from + vector * (min(length, maxLength) / magnitude))
    }

    /// The end of the shaft: the base of a head `headLength` long (the start when the arrow is no longer than that).
    func shaftEnd(headLength: Double) -> Vec2 { from + direction * max(length - headLength, 0) }

    /// The head triangle: the tip, then the two base corners `width` apart at the shaft's end.
    func head(length headLength: Double, width: Double) -> [Vec2] {
        let base = shaftEnd(headLength: headLength), side = Vec2(-direction.y, direction.x) * (width / 2)
        return [to, base + side, base - side]
    }
}

/// A failure the presenter injects for tests (`failNextDraw`).
enum PlaygroundDrawError: Error, Equatable {
    /// The injected failure.
    case injected
}

/// Draws Physics Playground and owns its presentation state (the scene nodes).
@MainActor
final class PlaygroundPresenter: ExperiencePresenter {
    /// The stage size in metres.
    nonisolated static let stageSize = WorldSettings.defaultStage
    /// The wall thickness in metres.
    nonisolated static let wallThickness = WorldSimulation.wallThickness
    /// The view's width and height in metres: the stage and a wall on each side.
    nonisolated static let viewWidth = stageSize.x + 2 * wallThickness, viewHeight = stageSize.y + 2 * wallThickness
    /// The stage point at the centre of the view.
    nonisolated static let viewCenter = Vec2(stageSize.x / 2, stageSize.y / 2)
    /// The clear colour around the view.
    nonisolated static let letterboxColor = Vec4(0.02, 0.02, 0.03, 1)
    /// The stage background colour (a dark navy).
    nonisolated static let stageColor = Vec4(0.06, 0.08, 0.12, 1)
    /// The wall colour.
    nonisolated static let wallColor = Vec4(0.30, 0.32, 0.36, 1)
    /// The fill and edge of a body whose material is not in the catalog.
    nonisolated static let fallbackFill = Vec4(0.6, 0.6, 0.6, 1), fallbackEdge = Vec4(0.35, 0.35, 0.35, 1)
    /// The factors a static body's fill and edge are darkened by.
    nonisolated static let staticFillFactor = 0.55, staticEdgeFactor = 0.7
    /// The width of outlines, radius lines and hatch lines in metres.
    nonisolated static let edgeWidth = 0.04
    /// The number of points of a circle's ring (closed: the last equals the first).
    nonisolated static let ringPoints = 33
    /// The spacing of the hatch of a static body in metres.
    nonisolated static let hatchSpacing = 0.25
    /// The z of the stage, the walls, the springs and their anchor dots, the body fills, the outlines and marks, the
    /// hatch and the letterbox masks.
    nonisolated static let stageZ = 0, wallZ = 1, springZ = 2, fillZ = 3, edgeZ = 4, hatchZ = 5, maskZ = 9
    /// The colour of the springs and their anchor dots (a pale straw).
    nonisolated static let springColor = Vec4(0.92, 0.86, 0.55, 1)
    /// The width of a spring's zigzag in metres.
    nonisolated static let springWidth = 0.03
    /// The number of coils of a spring's zigzag (each coil one peak to each side).
    nonisolated static let springCoils = 8
    /// The distance of a coil's peaks from the spring's axis in metres.
    nonisolated static let springAmplitude = 0.12
    /// The share of a spring's length taken by the straight lead at each end.
    nonisolated static let springLead = 0.1
    /// The radius of a spring's anchor dots in metres.
    nonisolated static let anchorDotRadius = 0.06
    /// The number of points of a spring's zigzag: both anchors, both lead ends and two peaks per coil.
    nonisolated static var springPoints: Int { 4 + 2 * springCoils }
    /// The stage point (metres) near the floor at the stage's middle where the frame probe is taken.
    nonisolated static let probePoint = Vec2(5, 0.75)
    /// The clearance around the probe point (metres) a body's bounding circle must keep for the probe to be taken.
    nonisolated static let probeMargin = 0.3
    /// The z of the overlays (arrows, grab line, selection ring and pin dots): above the bodies, under the masks.
    nonisolated static let overlayZ = 6
    /// The seconds of motion a velocity arrow shows: its length is 0.25 s × |v| metres.
    nonisolated static let velocityArrowSeconds = 0.25
    /// The metres per newton of a force arrow.
    nonisolated static let forceArrowScale = 0.05
    /// The longest arrow in metres.
    nonisolated static let maxArrowLength = 2.0
    /// The length and the width of an arrowhead in metres.
    nonisolated static let arrowHeadLength = 0.12, arrowHeadWidth = 0.12
    /// The width of an arrow's shaft in metres.
    nonisolated static let arrowShaftWidth = 0.04
    /// The width of the grab line in metres.
    nonisolated static let grabLineWidth = 0.02
    /// The gap between the selected body's bounding circle and its ring, and the radius of a pinned body's dot, in
    /// metres.
    nonisolated static let selectionGap = 0.1, pinDotRadius = 0.08
    /// The colours of the velocity, weight and spring-force arrows.
    nonisolated static let arrowColors: [PlaygroundArrow.Kind: Vec4] = [
        .velocity: Vec4(0.45, 0.85, 0.95, 1), .weight: Vec4(0.95, 0.6, 0.25, 1), .spring: Vec4(0.55, 0.9, 0.45, 1),
    ]
    /// The colour of the grab line, the selection ring and the pin dots.
    nonisolated static let grabColor = Vec4(0.95, 0.95, 0.95, 1), selectionColor = Vec4(0.98, 0.85, 0.2, 1),
                           pinColor = Vec4(0.9, 0.25, 0.3, 1)

    let experienceID: ExperienceID
    let mirror = PlaygroundMirror()

    /// Set by a test to make the next draw throw `PlaygroundDrawError.injected` (the seam clears itself).
    var failNextDraw = false
    /// Whether the scene is set up.
    private(set) var isLive = false
    /// The last core drawn or described.
    private(set) var lastCore: PlaygroundCore?
    /// The scale of the last frame (pixels per metre) and its canvas size in pixels.
    private(set) var lastScale = 0.0, lastCanvas = Vec2(0, 0)
    /// The number of bodies drawn in the last frame and how many of them were hatched as static.
    private(set) var lastBodiesDrawn = 0, lastStaticDrawn = 0
    /// The number of springs drawn in the last frame.
    private(set) var lastSpringsDrawn = 0

    private let clear = ClearColorScene(red: 0, green: 0, blue: 0)
    private var primitives: PrimitiveRenderer?
    private let root = SceneNode(id: "playground")
    /// The stage background.
    let stage = SceneNode(id: "stage", z: PlaygroundPresenter.stageZ)
    /// The four walls: floor, ceiling, left, right.
    private(set) var wallNodes: [SceneNode] = []
    /// The fill, outline, rotation mark and hatch node of each body slot.
    private(set) var fillNodes: [SceneNode] = [], edgeNodes: [SceneNode] = [], markNodes: [SceneNode] = [],
                     hatchNodes: [SceneNode] = []
    /// The zigzag and the two anchor dots (end A, end B) of each spring slot.
    private(set) var springNodes: [SceneNode] = [], anchorNodes: [(a: SceneNode, b: SceneNode)] = []
    /// The shaft and the head of each arrow kind (velocity, weight, spring) of each body slot (feature 084).
    private(set) var shaftNodes: [[SceneNode]] = [], headNodes: [[SceneNode]] = []
    /// The pin dot of each body slot, the selection ring and the grab line.
    private(set) var pinNodes: [SceneNode] = []
    let selectionNode = SceneNode(id: "selection", z: PlaygroundPresenter.overlayZ)
    let grabNode = SceneNode(id: "grab", z: PlaygroundPresenter.overlayZ)
    /// The number of arrows of each kind drawn in the last frame.
    private(set) var lastArrowsDrawn: [PlaygroundArrow.Kind: Int] = [:]
    private var maskNodes: [SceneNode] = []
    /// The canvas gestures (feature 084).
    private(set) var gestures = PlaygroundGestures()
    /// The port of the last canvas pointer event: a held tap or a long press held still is resolved through it on a
    /// frame tick.
    private var gesturePort: ExperienceActionPort?

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
        root.add(stage)
        for index in 0..<4 {
            let node = SceneNode(id: "wall\(index)", z: Self.wallZ)
            root.add(node)
            wallNodes.append(node)
        }
        for slot in 0..<ForceLevels.maxSprings {
            let line = SceneNode(id: "s\(slot)", z: Self.springZ)
            let a = SceneNode(id: "s\(slot).a", z: Self.springZ), b = SceneNode(id: "s\(slot).b", z: Self.springZ)
            for node in [line, a, b] { root.add(node) }
            springNodes.append(line)
            anchorNodes.append((a, b))
        }
        for slot in 0..<PhysicsWorld.maxBodies {
            let fill = SceneNode(id: "b\(slot)", z: Self.fillZ)
            let edge = SceneNode(id: "b\(slot).edge", z: Self.edgeZ)
            let mark = SceneNode(id: "b\(slot).mark", z: Self.edgeZ)
            let hatch = SceneNode(id: "b\(slot).hatch", z: Self.hatchZ)
            for node in [fill, edge, mark, hatch] { root.add(node) }
            fillNodes.append(fill)
            edgeNodes.append(edge)
            markNodes.append(mark)
            hatchNodes.append(hatch)
        }
        for slot in 0..<PhysicsWorld.maxBodies {
            var shafts: [SceneNode] = [], heads: [SceneNode] = []
            for kind in PlaygroundArrow.Kind.allCases {
                let shaft = SceneNode(id: "b\(slot).arrow\(kind.rawValue)", z: Self.overlayZ)
                let head = SceneNode(id: "b\(slot).arrow\(kind.rawValue).head", z: Self.overlayZ)
                root.add(shaft)
                root.add(head)
                shafts.append(shaft)
                heads.append(head)
            }
            shaftNodes.append(shafts)
            headNodes.append(heads)
            let pin = SceneNode(id: "b\(slot).pin", z: Self.overlayZ)
            root.add(pin)
            pinNodes.append(pin)
        }
        root.add(selectionNode)
        root.add(grabNode)
        for side in 0..<4 {
            let node = SceneNode(id: "mask\(side)", z: Self.maskZ)
            root.add(node)
            maskNodes.append(node)
        }
    }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
        isLive = true
    }

    func draw(_ core: PlaygroundCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw PlaygroundDrawError.injected
        }
        sync(core)
        clear.red = Float(Self.letterboxColor.x)
        clear.green = Float(Self.letterboxColor.y)
        clear.blue = Float(Self.letterboxColor.z)
        try clear.render(context, frame: frame)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        layOut(core, width: width, height: height)
        if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
        try primitives?.draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(width, height), scale: 1))
        // A held tap whose double-tap window closed, or a long press held still, is sent on the frame tick (an action
        // at the next step, recorded like any other; the drawing itself changes nothing).
        if let port = gesturePort {
            advanceGestures(by: frame.delta) { port.send($0, $1) }
        }
    }

    func teardown(_ context: RenderContext) {
        isLive = false
        suspended()
        primitives?.release()
        primitives = nil
    }

    // MARK: Geometry

    /// The uniform scale (pixels per metre) that fits the 12 × 10 m view into `width` × `height` pixels.
    nonisolated static func scale(width: Double, height: Double) -> Double {
        min(width / viewWidth, height / viewHeight)
    }

    /// The world point (pixels from the canvas centre, y up) of the stage point `p` (metres) at `scale`.
    nonisolated static func world(_ p: Vec2, scale: Double) -> Vec2 {
        Vec2((p.x - viewCenter.x) * scale, (p.y - viewCenter.y) * scale)
    }

    /// `local` rotated by `angle` radians (counter-clockwise) and moved to `center`.
    nonisolated static func place(_ local: Vec2, center: Vec2, angle: Double) -> Vec2 {
        let c = cos(angle), s = sin(angle)
        return Vec2(center.x + local.x * c - local.y * s, center.y + local.x * s + local.y * c)
    }

    /// The four corners of a box of `half` extents at `center` and `angle` (counter-clockwise from bottom-left).
    nonisolated static func corners(half: Vec2, center: Vec2, angle: Double) -> [Vec2] {
        [Vec2(-half.x, -half.y), Vec2(half.x, -half.y), Vec2(half.x, half.y), Vec2(-half.x, half.y)]
            .map { place($0, center: center, angle: angle) }
    }

    /// The closed ring of ``ringPoints`` points of `radius` around `center`.
    nonisolated static func ring(center: Vec2, radius: Double) -> [Vec2] {
        (0..<ringPoints).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(ringPoints - 1)
            return center + Vec2(cos(angle) * radius, sin(angle) * radius)
        }
    }

    /// The end of the radius line of a circle of `radius` at `center` turned by `angle`.
    nonisolated static func radiusEnd(center: Vec2, radius: Double, angle: Double) -> Vec2 {
        center + Vec2(cos(angle) * radius, sin(angle) * radius)
    }

    /// The hatch inside `shape` at `center` and `angle`: a path through lines across the shape (bottom to top, then
    /// top to bottom) at x steps of about ``hatchSpacing`` (inside a circle, the chord ends at each x).
    nonisolated static func hatch(_ shape: Shape2D, center: Vec2, angle: Double) -> [Vec2] {
        let halfWidth: Double
        switch shape {
        case .circle(let radius): halfWidth = radius
        case .box(let half): halfWidth = half.x
        }
        let count = max(1, Int((2 * halfWidth / hatchSpacing).rounded(.down)))
        let step = 2 * halfWidth / Double(count + 1)
        var points: [Vec2] = []
        for k in 1...count {
            let x = -halfWidth + Double(k) * step
            let reach: Double
            switch shape {
            case .circle(let radius): reach = (max(radius * radius - x * x, 0)).squareRoot()
            case .box(let half): reach = half.y
            }
            let ends = [Vec2(x, -reach), Vec2(x, reach)]
            let ordered = k % 2 == 1 ? ends : Array(ends.reversed())
            points += ordered.map { place($0, center: center, angle: angle) }
        }
        return points
    }

    /// The zigzag of a spring from the world point `a` to the world point `b` (metres): `a`, the end of the lead
    /// (``springLead`` of the length along the axis), two peaks per coil (``springCoils`` coils) alternately
    /// ``springAmplitude`` to the left and to the right of the axis, evenly spaced between the leads, the start of the
    /// other lead, and `b` — ``springPoints`` points. Two coincident anchors give the straight segment [a, b].
    nonisolated static func zigzag(from a: Vec2, to b: Vec2) -> [Vec2] {
        let d = b - a, length = d.length
        guard length > 1e-9 else { return [a, b] }
        let axis = d * (1 / length), side = Vec2(-axis.y, axis.x)
        let peaks = 2 * springCoils
        var points = [a, a + d * springLead]
        for k in 0..<peaks {
            let t = springLead + (1 - 2 * springLead) * (Double(k) + 0.5) / Double(peaks)
            let sign: Double = k % 2 == 0 ? 1 : -1
            points.append(a + d * t + side * (sign * springAmplitude))
        }
        points += [a + d * (1 - springLead), b]
        return points
    }

    /// The world anchors (metres) of `spring` in `world`, nil when a body end names a missing body.
    nonisolated static func anchors(_ spring: WorldSpring, in world: PhysicsWorld) -> (a: Vec2, b: Vec2)? {
        guard let a = world.anchorPosition(spring.a), let b = world.anchorPosition(spring.b), a.isFinite, b.isFinite
        else { return nil }
        return (a, b)
    }

    /// The distance from `p` to the segment from `a` to `b`.
    nonisolated static func distance(from p: Vec2, toSegment a: Vec2, _ b: Vec2) -> Double {
        let d = b - a, lengthSquared = d.x * d.x + d.y * d.y
        guard lengthSquared > 0 else { return (p - a).length }
        let t = min(max(((p.x - a.x) * d.x + (p.y - a.y) * d.y) / lengthSquared, 0), 1)
        return (p - (a + d * t)).length
    }

    /// A material colour as a vector.
    nonisolated static func vector(_ color: RGB) -> Vec4 { Vec4(color.r, color.g, color.b, 1) }

    /// `color` with its red, green and blue multiplied by `factor`.
    nonisolated static func darkened(_ color: Vec4, _ factor: Double) -> Vec4 {
        Vec4(color.x * factor, color.y * factor, color.z * factor, color.w)
    }

    /// The fill and edge colours of `body` (darkened when static; grey when its material is unknown).
    nonisolated static func colors(_ body: PhysicsBody) -> (fill: Vec4, edge: Vec4) {
        var fill = fallbackFill, edge = fallbackEdge
        if let material = PlaygroundCore.catalog.material(id: body.materialId) {
            fill = vector(material.fill)
            edge = vector(material.edge)
        }
        guard body.isStatic else { return (fill, edge) }
        return (darkened(fill, staticFillFactor), darkened(edge, staticEdgeFactor))
    }

    /// Places every node for a canvas of `width` × `height` pixels (world = pixels from the centre, y up). Reads
    /// `core` only.
    func layOut(_ core: PlaygroundCore, width: Double, height: Double) {
        let world = core.world
        let s = Self.scale(width: width, height: height)
        lastScale = s
        lastCanvas = Vec2(width, height)
        let onePixel = 1.0
        func map(_ p: Vec2) -> Vec2 { Self.world(p, scale: s) }
        func px(_ metres: Double) -> Double { max(metres * s, onePixel) }

        stage.primitive = .rect(Vec2(Self.stageSize.x * s, Self.stageSize.y * s))
        stage.position = map(Self.viewCenter)
        stage.color = Self.stageColor
        for (node, wall) in zip(wallNodes, WorldSimulation.walls(for: world.settings)) {
            guard case .box(let half) = wall.shape else { node.primitive = nil; continue }
            node.primitive = .rect(Vec2(2 * half.x * s, 2 * half.y * s))
            node.position = map(wall.pose.position)
            node.color = Self.wallColor
        }

        var springsDrawn = 0
        for slot in 0..<ForceLevels.maxSprings {
            let line = springNodes[slot], (dotA, dotB) = anchorNodes[slot]
            for node in [line, dotA, dotB] {
                node.primitive = nil
                node.position = .zero
                node.color = Self.springColor
            }
            guard slot < world.springs.count, let ends = Self.anchors(world.springs[slot], in: world) else { continue }
            line.primitive = .polyline(Self.zigzag(from: ends.a, to: ends.b).map(map), width: px(Self.springWidth))
            dotA.primitive = .circle(px(Self.anchorDotRadius))
            dotA.position = map(ends.a)
            dotB.primitive = .circle(px(Self.anchorDotRadius))
            dotB.position = map(ends.b)
            springsDrawn += 1
        }
        lastSpringsDrawn = springsDrawn

        var drawn = 0, hatched = 0
        for slot in 0..<PhysicsWorld.maxBodies {
            let fill = fillNodes[slot], edge = edgeNodes[slot], mark = markNodes[slot], hatch = hatchNodes[slot]
            for node in [fill, edge, mark, hatch] { node.primitive = nil; node.position = .zero }
            guard slot < world.bodies.count else { continue }
            let body = world.bodies[slot]
            guard body.isFinite else { continue }
            let (fillColor, edgeColor) = Self.colors(body)
            fill.color = fillColor
            edge.color = edgeColor
            mark.color = edgeColor
            hatch.color = edgeColor
            switch body.shape {
            case .circle(let radius):
                fill.primitive = .circle(radius * s)
                fill.position = map(body.position)
                edge.primitive = .polyline(Self.ring(center: body.position, radius: radius).map(map),
                                           width: px(Self.edgeWidth))
                mark.primitive = .line(map(body.position),
                                       map(Self.radiusEnd(center: body.position, radius: radius, angle: body.angle)),
                                       width: px(Self.edgeWidth))
            case .box(let half):
                let corners = Self.corners(half: half, center: body.position, angle: body.angle)
                fill.primitive = .polygon(corners.map(map))
                edge.primitive = .polyline((corners + [corners[0]]).map(map), width: px(Self.edgeWidth))
            }
            if body.isStatic {
                hatch.primitive = .polyline(Self.hatch(body.shape, center: body.position, angle: body.angle).map(map),
                                            width: px(Self.edgeWidth))
                hatched += 1
            }
            drawn += 1
        }
        lastBodiesDrawn = drawn
        lastStaticDrawn = hatched
        layOutOverlays(core, scale: s)

        // Letterbox masks: everything outside the view is covered in the clear colour.
        let halfW = Self.viewWidth / 2 * s, halfH = Self.viewHeight / 2 * s
        let big = Vec2(max(width, 1) * 2, max(height, 1) * 2)
        let centres = [Vec2(-halfW - big.x / 2, 0), Vec2(halfW + big.x / 2, 0),
                       Vec2(0, halfH + big.y / 2), Vec2(0, -halfH - big.y / 2)]
        for (node, centre) in zip(maskNodes, centres) {
            node.primitive = .rect(big)
            node.position = centre
            node.color = Self.letterboxColor
        }
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: PlaygroundCore) {
        lastCore = core
        let world = core.world
        if !mirror.ready { mirror.ready = true }
        if mirror.bodyCount != world.bodies.count { mirror.bodyCount = world.bodies.count }
        if mirror.paused != world.paused { mirror.paused = world.paused }
        if mirror.timeScaleIndex != world.timeScaleIndex { mirror.timeScaleIndex = world.timeScaleIndex }
        if mirror.gravityLevel != world.gravityLevel { mirror.gravityLevel = world.gravityLevel }
        if mirror.dragLevel != world.dragLevel { mirror.dragLevel = world.dragLevel }
        if mirror.stiffnessLevel != world.stiffnessLevel { mirror.stiffnessLevel = world.stiffnessLevel }
        let status = Self.status(world)
        if mirror.status != status { mirror.status = status }
        let forces = Self.forces(world)
        if mirror.forces != forces { mirror.forces = forces }
        let ids = world.bodies.map(\.id)
        if mirror.bodyIds != ids { mirror.bodyIds = ids }
        let selected = world.selectedId.flatMap { world.index(ofBody: $0) }.map { world.bodies[$0] }
        if mirror.selectedId != selected?.id { mirror.selectedId = selected?.id }
        if mirror.selectedCenter != selected?.position { mirror.selectedCenter = selected?.position }
        let selectedStatic = selected?.isStatic ?? false, selectedPinned = selected?.pinned ?? false
        if mirror.selectedStatic != selectedStatic { mirror.selectedStatic = selectedStatic }
        if mirror.selectedPinned != selectedPinned { mirror.selectedPinned = selectedPinned }
        if mirror.grabbedId != world.grab?.bodyId { mirror.grabbedId = world.grab?.bodyId }
        if mirror.grabTarget != world.grab?.target { mirror.grabTarget = world.grab?.target }
        let pinned = world.bodies.filter(\.pinned).count
        if mirror.pinnedCount != pinned { mirror.pinnedCount = pinned }
        if mirror.showVelocity != world.showVelocity { mirror.showVelocity = world.showVelocity }
        if mirror.showForces != world.showForces { mirror.showForces = world.showForces }
        let panel = PlaygroundPanel.measure(world)
        if mirror.panel != panel { mirror.panel = panel }
        let editing = Self.editing(world)
        if mirror.editing != editing { mirror.editing = editing }
    }

    /// The word of `index` in `words`, or "unknown" outside it.
    nonisolated private static func word(_ words: [String], _ index: Int) -> String {
        words.indices.contains(index) ? words[index] : "unknown"
    }

    /// The gravity levels as shown on the picker: "Off", "Moon", "Earth".
    nonisolated static let gravityTitles = ["Off", "Moon", "Earth"]
    /// The drag levels as shown on the picker: "None", "Low", "High".
    nonisolated static let dragTitles = ["None", "Low", "High"]
    /// The stiffness levels as shown on the picker: "Soft", "Medium", "Stiff", "Very stiff".
    nonisolated static let stiffnessTitles = ["Soft", "Medium", "Stiff", "Very stiff"]

    /// The gravity level in the description: "off", "Moon" or "Earth".
    nonisolated static func gravityWord(_ level: Int) -> String { word(["off", "Moon", "Earth"], level) }
    /// The drag level in the description: "none", "low" or "high".
    nonisolated static func dragWord(_ level: Int) -> String { word(["none", "low", "high"], level) }
    /// The stiffness level in the description: "soft", "medium", "stiff" or "very stiff".
    nonisolated static func stiffnessWord(_ level: Int) -> String {
        word(["soft", "medium", "stiff", "very stiff"], level)
    }

    /// The spoken value of a gravity level: "Off", "Moon, 1.62 metres per second squared", "Earth, 9.81 metres per
    /// second squared".
    nonisolated static func gravityValue(_ level: Int) -> String {
        guard let g = ForceLevels.gravityVector(level: level) else { return "Unknown" }
        return level == 0 ? "Off" : "\(gravityTitles[level]), \(number(-g.y)) metres per second squared"
    }
    /// The spoken value of a drag level: "None", "Low, 0.05 per second", "High, 1 per second".
    nonisolated static func dragValue(_ level: Int) -> String {
        guard let drag = ForceLevels.dragValue(level: level) else { return "Unknown" }
        return level == 0 ? "None" : "\(dragTitles[level]), \(number(drag)) per second"
    }
    /// The spoken value of a stiffness level: "Medium, 60 newtons per metre".
    nonisolated static func stiffnessValue(_ level: Int) -> String {
        guard let k = ForceLevels.stiffnessValue(level: level) else { return "Unknown" }
        return "\(stiffnessTitles[level]), \(number(k)) newtons per metre"
    }
    /// `value` without a trailing ".0" ("60", "1.62", "0.05").
    nonisolated static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    /// "no springs", "1 spring" or "2 springs".
    nonisolated static func springWords(_ count: Int) -> String {
        switch count {
        case ...0: return "no springs"
        case 1: return "1 spring"
        default: return "\(count) springs"
        }
    }

    /// The forces line: "2 springs, stiffness medium, gravity Earth, drag low".
    nonisolated static func forces(_ world: PhysicsWorld) -> String {
        "\(springWords(world.springs.count)), stiffness \(stiffnessWord(world.stiffnessLevel)), "
            + "gravity \(gravityWord(world.gravityLevel)), drag \(dragWord(world.dragLevel))"
    }

    /// The time scale as shown: "¼×", "½×", "1×" or "2×" ("?" outside 0…3).
    nonisolated static func timeScaleText(_ index: Int) -> String {
        ["¼×", "½×", "1×", "2×"].indices.contains(index) ? ["¼×", "½×", "1×", "2×"][index] : "?"
    }

    /// The time scale in words: "quarter speed", "half speed", "normal speed" or "double speed".
    nonisolated static func timeScaleWords(_ index: Int) -> String {
        let words = ["quarter speed", "half speed", "normal speed", "double speed"]
        return words.indices.contains(index) ? words[index] : "unknown speed"
    }

    /// "no bodies", "1 body" or "7 bodies".
    nonisolated static func bodyWords(_ count: Int) -> String {
        switch count {
        case ...0: return "no bodies"
        case 1: return "1 body"
        default: return "\(count) bodies"
        }
    }

    /// "running" or "paused".
    nonisolated static func stateWord(_ world: PhysicsWorld) -> String { world.paused ? "paused" : "running" }

    /// The status line: "7 bodies, running, normal speed".
    nonisolated static func status(_ world: PhysicsWorld) -> String {
        "\(bodyWords(world.bodies.count)), \(stateWord(world)), \(timeScaleWords(world.timeScaleIndex))"
    }

    /// The canvas description, for example "Physics Playground: 10 bodies, running, normal speed (time scale 1×);
    /// 2 springs, stiffness medium, gravity Earth, drag low; none pinned, no selection, arrows off."
    nonisolated static func description(_ world: PhysicsWorld) -> String {
        "Physics Playground: \(status(world)) (time scale \(timeScaleText(world.timeScaleIndex))); \(forces(world)); "
            + "\(editing(world))."
    }

    /// "none pinned", "1 pinned" or "3 pinned".
    nonisolated static func pinnedWords(_ count: Int) -> String {
        count <= 0 ? "none pinned" : "\(count) pinned"
    }

    /// "a circle" or "a box".
    nonisolated static func shapeWords(_ shape: Shape2D) -> String {
        switch shape {
        case .circle: return "a circle"
        case .box: return "a box"
        }
    }

    /// The selection in words: "no selection", or "body 7 selected (a box, pinned)".
    nonisolated static func selectionWords(_ world: PhysicsWorld) -> String {
        guard let id = world.selectedId, let index = world.index(ofBody: id) else { return "no selection" }
        let body = world.bodies[index]
        let state = body.isStatic ? ", static" : body.pinned ? ", pinned" : ""
        return "body \(id) selected (\(shapeWords(body.shape))\(state))"
    }

    /// The overlays in words: "arrows off", "velocity arrows on", "force arrows on" or "velocity and force arrows on".
    nonisolated static func overlayWords(_ world: PhysicsWorld) -> String {
        switch (world.showVelocity, world.showForces) {
        case (false, false): return "arrows off"
        case (true, false): return "velocity arrows on"
        case (false, true): return "force arrows on"
        case (true, true): return "velocity and force arrows on"
        }
    }

    /// The editing line: "none pinned, no selection, arrows off", with ", body 8 held" before the overlays while a
    /// body is grabbed.
    nonisolated static func editing(_ world: PhysicsWorld) -> String {
        let held = world.grab.map { ", body \($0.bodyId) held" } ?? ""
        return "\(pinnedWords(world.bodies.filter(\.pinned).count)), \(selectionWords(world))\(held), "
            + overlayWords(world)
    }

    /// The description of `core`'s world.
    func describe(_ core: PlaygroundCore) -> String {
        sync(core)
        return Self.description(core.world)
    }

    /// The canvas fraction (x from the left, y from the top) of the stage point `p` in the last frame; without a frame
    /// the view is assumed to fill the canvas height.
    func canvasFraction(of p: Vec2) -> Vec2 {
        guard lastScale > 0, lastCanvas.x > 0, lastCanvas.y > 0 else {
            return Vec2(0.5, 0.5 - (p.y - Self.viewCenter.y) / Self.viewHeight)
        }
        let w = Self.world(p, scale: lastScale)
        return Vec2(0.5 + w.x / lastCanvas.x, 0.5 - w.y / lastCanvas.y)
    }

    /// The `FrameColorClass` raw value of a colour (0…1 channels) by the frame checks' rules, nil when a channel
    /// difference or the luma lies within 4 of 255 of a threshold (8-bit rounding could change the class).
    nonisolated static func colorClass(red: Double, green: Double, blue: Double) -> String? {
        let r = red * 255, g = green * 255, b = blue * 255
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let margin = 4.0
        let checks = [luma - 40, luma - 215, r - g - 30, r - b - 30, g - r - 30, g - b - 30, b - r - 30, b - g - 30,
                      max(r, g, b) - min(r, g, b) - 30]
        guard checks.allSatisfy({ abs($0) > margin }) else { return nil }
        if luma < 40 { return FrameColorClass.dark.rawValue }
        if luma > 215, max(r, g, b) - min(r, g, b) < 30 { return FrameColorClass.light.rawValue }
        if r - g >= 30, r - b >= 30 { return FrameColorClass.red.rawValue }
        if g - r >= 30, g - b >= 30 { return FrameColorClass.green.rawValue }
        if b - r >= 30, b - g >= 30 { return FrameColorClass.blue.rawValue }
        return FrameColorClass.other.rawValue
    }

    /// The colour class of the stage background: `dark`.
    nonisolated static var colorClassOfStage: String? {
        colorClass(red: stageColor.x, green: stageColor.y, blue: stageColor.z)
    }

    /// One probe on the stage background near the floor at the middle, expecting `dark`; none while a body's bounding
    /// circle, or a spring's zigzag and anchor dots (its axis widened by the coil amplitude and the dot radius), comes
    /// within ``probeMargin`` of that point.
    func probes(_ core: PlaygroundCore) -> [FrameProbe] {
        guard let expected = Self.colorClassOfStage else { return [] }
        for body in core.world.bodies {
            if (body.position - Self.probePoint).length < body.boundingRadius + Self.probeMargin { return [] }
        }
        let springReach = max(Self.springAmplitude, Self.anchorDotRadius) + Self.springWidth
        for spring in core.world.springs {
            guard let ends = Self.anchors(spring, in: core.world) else { continue }
            if Self.distance(from: Self.probePoint, toSegment: ends.a, ends.b) < springReach + Self.probeMargin {
                return []
            }
        }
        // Feature 084: every overlay — arrows (widened by half the head's width), the grab line, the selection ring
        // and pin dots (inside their bodies) — keeps the margin too.
        let arrowReach = max(Self.arrowHeadWidth / 2, Self.arrowShaftWidth)
        for item in Self.arrows(core.world, forces: core.forces) {
            let arrow = item.arrow
            if Self.distance(from: Self.probePoint, toSegment: arrow.from, arrow.to) < arrowReach + Self.probeMargin {
                return []
            }
        }
        if let line = Self.grabLine(core.world),
           Self.distance(from: Self.probePoint, toSegment: line.from, line.to) < Self.grabLineWidth + Self.probeMargin {
            return []
        }
        if let id = core.world.selectedId, let index = core.world.index(ofBody: id) {
            let body = core.world.bodies[index]
            let reach = body.boundingRadius + Self.selectionGap + Self.edgeWidth + Self.probeMargin
            if (body.position - Self.probePoint).length < reach { return [] }
        }
        let fraction = canvasFraction(of: Self.probePoint)
        return [FrameProbe(name: "stage", x: fraction.x, y: fraction.y, expected: expected)].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(PlaygroundControls(port: port, mirror: mirror))
    }

    /// Every action has a native control (the three level pickers, the selection, pin, delete, add, hold and
    /// direction buttons and the two overlay toggles included).
    var nativeActions: Set<String> { Set(PlaygroundCore.actionIDs) }

    // MARK: Gestures (feature 084)

    /// The seven edit actions the canvas gestures send.
    var gestureActions: Set<String> { PlaygroundGestures.gestureActions }

    /// Turns a canvas pointer event into edit actions against the last drawn world and sends each through `port`;
    /// nothing happens before a state was seen.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        gesturePort = port
        pointer(event, viewSize: viewSize) { port.send($0, $1) }
    }

    /// The pointer event `event` turned into edit actions sent through `send` (tests record them); the shape picker's
    /// kind is the one an add uses.
    func pointer(_ event: PointerEvent, viewSize: Vec2, send: PlaygroundGestures.Send) {
        guard let core = lastCore else { return }
        let kind = BodyKind(rawValue: mirror.shapeKind) ?? .circle
        gestures.handle(event, viewSize: viewSize, world: core.world, kind: kind, send: send)
    }

    /// Advances the gestures by `seconds` of frame time against the last drawn world, sending what comes due through
    /// `send`.
    func advanceGestures(by seconds: Double, send: PlaygroundGestures.Send) {
        guard let core = lastCore else { return }
        gestures.advance(by: seconds, world: core.world, send: send)
    }

    /// The experience was suspended or is leaving: every touch, held tap and grab finger is forgotten (nothing is sent;
    /// the suspension's `edit.release` is sent by `PlaygroundExperience` before it suspends).
    func suspended() {
        gestures.reset()
        gesturePort = nil
    }

    // MARK: Overlays (feature 084)

    /// The overlay arrows of `world` with the measured `forces`, by body slot and kind: velocity arrows when
    /// `showVelocity` is on, weight and spring-force arrows when `showForces` is on, for every non-static, finite body
    /// (the spring force only while `forces` belongs to the world's tick); a zero vector gives no arrow.
    nonisolated static func arrows(_ world: PhysicsWorld, forces: ForceMeasurement,
                                   catalog: MaterialCatalog = PlaygroundCore.catalog)
        -> [(slot: Int, kind: PlaygroundArrow.Kind, arrow: PlaygroundArrow)] {
        guard world.showVelocity || world.showForces else { return [] }
        let current = forces.isCurrent(for: world)
        var arrows: [(slot: Int, kind: PlaygroundArrow.Kind, arrow: PlaygroundArrow)] = []
        for (slot, body) in world.bodies.enumerated() where !body.isStatic && body.isFinite {
            if world.showVelocity,
               let arrow = PlaygroundArrow.make(from: body.position, vector: body.velocity,
                                                scale: velocityArrowSeconds, maxLength: maxArrowLength) {
                arrows.append((slot, .velocity, arrow))
            }
            guard world.showForces else { continue }
            let weight = ForceMeasurement.weight(of: body, in: world, catalog: catalog)
            if let arrow = PlaygroundArrow.make(from: body.position, vector: weight, scale: forceArrowScale,
                                                maxLength: maxArrowLength) {
                arrows.append((slot, .weight, arrow))
            }
            if current,
               let arrow = PlaygroundArrow.make(from: body.position, vector: forces.springForce(on: body.id),
                                                scale: forceArrowScale, maxLength: maxArrowLength) {
                arrows.append((slot, .spring, arrow))
            }
        }
        return arrows
    }

    /// The grab line of `world` in metres: from the grabbed body's anchor (through its pose) to the target; nil without
    /// a grab or when the body is missing.
    nonisolated static func grabLine(_ world: PhysicsWorld) -> (from: Vec2, to: Vec2)? {
        guard let grab = world.grab, let index = world.index(ofBody: grab.bodyId) else { return nil }
        let anchor = world.bodies[index].pose.toWorld(grab.localAnchor)
        guard anchor.isFinite, grab.target.isFinite else { return nil }
        return (anchor, grab.target)
    }

    /// Places the overlay nodes of `core` at `scale` pixels per metre (reads `core` only).
    func layOutOverlays(_ core: PlaygroundCore, scale s: Double) {
        let world = core.world
        func map(_ p: Vec2) -> Vec2 { Self.world(p, scale: s) }
        func px(_ metres: Double) -> Double { max(metres * s, 1) }
        for slot in 0..<PhysicsWorld.maxBodies {
            for node in shaftNodes[slot] + headNodes[slot] + [pinNodes[slot]] {
                node.primitive = nil
                node.position = .zero
            }
        }
        var counts: [PlaygroundArrow.Kind: Int] = [:]
        for item in Self.arrows(world, forces: core.forces) where item.slot < PhysicsWorld.maxBodies {
            let shaft = shaftNodes[item.slot][item.kind.rawValue], head = headNodes[item.slot][item.kind.rawValue]
            let color = Self.arrowColors[item.kind] ?? Self.grabColor
            let base = item.arrow.shaftEnd(headLength: Self.arrowHeadLength)
            if (base - item.arrow.from).length > 0 {
                shaft.primitive = .line(map(item.arrow.from), map(base), width: px(Self.arrowShaftWidth))
            }
            head.primitive = .polygon(item.arrow.head(length: Self.arrowHeadLength, width: Self.arrowHeadWidth)
                .map(map))
            shaft.color = color
            head.color = color
            counts[item.kind, default: 0] += 1
        }
        lastArrowsDrawn = counts
        for (slot, body) in world.bodies.enumerated() where slot < PhysicsWorld.maxBodies && body.pinned {
            pinNodes[slot].primitive = .circle(px(Self.pinDotRadius))
            pinNodes[slot].position = map(body.position)
            pinNodes[slot].color = Self.pinColor
        }
        selectionNode.primitive = nil
        selectionNode.position = .zero
        if let id = world.selectedId, let index = world.index(ofBody: id), world.bodies[index].isFinite {
            let body = world.bodies[index]
            selectionNode.primitive = .polyline(
                Self.ring(center: body.position, radius: body.boundingRadius + Self.selectionGap).map(map),
                width: px(Self.edgeWidth))
            selectionNode.color = Self.selectionColor
        }
        grabNode.primitive = nil
        grabNode.position = .zero
        if let line = Self.grabLine(world) {
            grabNode.primitive = .line(map(line.from), map(line.to), width: px(Self.grabLineWidth))
            grabNode.color = Self.grabColor
        }
    }
}
