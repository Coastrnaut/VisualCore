// BinaryGardensPicker — feature 504 (R02-G21-04) T-R02G2104-002 (FR-R02G2104-004, 007, 009, 010, 012;
// SC-R02G2104-001, 004; clarifications Q1, Q3, Q4; research R1–R3, R7, R11). Analytic, deterministic picking of a touch
// in the drawn Binary Gardens star system. Everything is projected through the drawn camera
// (`BinaryGardensSceneGeometry.camera(aspect:orbit:)` with the view's aspect width / height) into view points (origin
// top left, x right, y down; the size is the view's size in points). A world extent e at a centre c becomes
// e / (depth · tan(fovY / 2)) · height / 2 view points, depth c's distance from the eye along the view axis. The
// positions are those of the drawn snapshot (`BinaryGardensSceneGeometry.drawnSnapshot(_:)`), so what the finger seems
// to touch is what is picked. Of several hits the target drawn last wins, in the reverse of the scene's painter's
// order (clarification Q1, research R11):
//   1. the actions bars: the finger cast onto the plane z = 0 inside a bar's rectangle is empty space (they are drawn
//      over everything but the glow);
//   2. a gauge row j: the finger cast onto z = 0 inside row j's plate rectangle (x −0.95 … 1.22, y_j ± 0.045); the
//      plates never overlap and the 0.01 gap between two of them is empty space;
//   3. the bodies front to back from the drawn eye (the reverse of the scene's back-to-front sort): for a star, first
//      its luminosity pip row — within ``BinaryGardensPicker/markerAllowance`` (12) points of the projected segment
//      from its first to its last pip centre (a point for a single level), the pips facing the drawn eye — then its
//      disc (its projected radius grown by 12 points); for a world, its projected radius 0.07 grown by 12 points (a
//      world's own pips are part of nothing);
//   4. a star ring (later ring indices first): within 12 points of its projected 48-gon at the drawn tilt;
//   5. the tilt dial (only when T_max > 0): within 12 points of the projected segment from its first to its last pip;
//   6. the system disc: the finger cast onto z = 0 within radius 0.95 of the origin;
//   7. anything else (world orbits, trails, backdrop, glow) is empty space, as is unusable input (a non-finite point, a
//      size that is not finite and positive).
// The drag targets read the given snapshot (the touch-down one, its committed arrangement): a star's projected orbit
// tangent u is the projection of its ring vertex at table step s + 1 minus that at s − 1, s = (θ + ω · t) mod 48 at the
// shown tick t (tick 48 giving θ), on its ring at the current tilt; a star drag is a phase drag when the travel's
// component along u is strictly greater than its component across u, else a ring drag (|u| below
// ``BinaryGardensPicker/tangentFloor`` (0.5 points): a ring drag), overridden by the star's freedoms (only one of ring
// and phase adjustable: that one; neither: nil); the ring target is the ring index whose vertex at s projects nearest
// the finger, the phase target the grid phase p ∈ {0, g, …, 48 − g} whose vertex at (p + ω · t) mod 48 on the star's
// ring projects nearest (lower index or phase on ties); a pip or dial tap takes the pip whose projected centre is
// nearest (lower index on ties); a luminosity or tilt drag counts travel: clamp(start + round(dx / 32), 0, upper),
// halves away from zero; the tick under the finger is clamp(⌊(x + 0.9) / (1.8 / 48)⌋ + 1, 1, 48) for the cast x
// clamped to the cells. Presentation only: the picker reads the snapshot and the view orbit and never changes the
// kernel. Modelled on feature 494's `MushroomWeatherPicker`.
import Foundation

/// What a touch picked in the Binary Gardens star system (feature 504).
public enum BinaryGardensPick: Sendable, Equatable {
    /// World `j`'s gauge row: the finger cast onto the base plane inside its plate.
    case gauge(Int)
    /// Star `i`'s luminosity pip row: within ``BinaryGardensPicker/markerAllowance`` of its projected segment.
    case pips(Int)
    /// Star `i`'s disc: its projected radius grown by ``BinaryGardensPicker/markerAllowance``.
    case star(Int)
    /// World `j`: its projected radius grown by ``BinaryGardensPicker/markerAllowance``.
    case world(Int)
    /// Star ring `index`: within ``BinaryGardensPicker/markerAllowance`` of its projected 48-gon.
    case ring(Int)
    /// The tilt dial: within ``BinaryGardensPicker/markerAllowance`` of its projected pip segment.
    case dial
    /// The system disc: the finger cast onto the base plane within radius 0.95, away from every other target.
    case disc
    /// Nothing: unusable input, the actions bars, or outside every target.
    case empty
}

/// How a star drag moves its star (feature 504): across its rings or along its orbit.
public enum BinaryGardensStarDragMode: Sendable, Equatable {
    /// To another ring (`star.ring`).
    case ring
    /// To another grid phase (`star.phase`).
    case phase
}

/// The analytic picker of the Binary Gardens star system (see the file header).
public enum BinaryGardensPicker {
    /// How many view points a target reaches beyond its projected size or polygon, 12.
    public static let markerAllowance: Double = 12
    /// How many view points of horizontal travel change a luminosity or tilt drag by one step, 32.
    public static let stepTravel: Double = 32
    /// The shortest projected orbit tangent in view points that can decide a phase drag, 0.5.
    public static let tangentFloor: Double = 0.5

    /// The drawn camera of a view of `size` points from `orbit` (clamped): aspect width / height. Nil for a size that
    /// is not finite and positive.
    public static func camera(size: SIMD2<Double>, orbit: BinaryGardensViewOrbit) -> BinaryGardensCamera? {
        guard usable(size) else { return nil }
        return BinaryGardensSceneGeometry.camera(aspect: size.x / size.y, orbit: orbit)
    }

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``BinaryGardensSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not finite
    /// or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: BinaryGardensCamera) -> SIMD2<Double>? {
        guard usable(size), let v = BinaryGardensSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The length in view points of a world extent `extent` at `centre` seen through `camera` in a view of `size`
    /// points: extent / (depth · tan(fovY / 2)) · height / 2, depth the centre's distance along the view axis. Nil when
    /// the centre is not in front of the eye or the size is unusable.
    public static func projectedExtent(_ extent: Double, at centre: SIMD3<Double>, size: SIMD2<Double>,
                                       camera: BinaryGardensCamera) -> Double? {
        typealias G = BinaryGardensSceneGeometry
        guard usable(size) else { return nil }
        let forward: SIMD3<Double> = G.viewBasis(camera).forward
        let depth: Double = G.dot(centre - camera.eye, forward)
        let tanHalf: Double = tan(camera.fovY / 2)
        guard depth.isFinite, depth > 0, tanHalf.isFinite, tanHalf > 0 else { return nil }
        let r: Double = extent / (depth * tanHalf) * size.y / 2
        return r.isFinite ? r : nil
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` (as
    /// drawn) from the camera of `orbit` (clamped) with aspect width / height, in the order of the file header: the
    /// actions bars (empty), a gauge row, the bodies front to back (a star's pip row before its disc), the rings (later
    /// first), the dial, the system disc, else ``BinaryGardensPick/empty`` (also for a non-finite point or a size that
    /// is not finite and positive). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: BinaryGardensSceneSnapshot,
                            orbit: BinaryGardensViewOrbit) -> BinaryGardensPick {
        typealias G = BinaryGardensSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(size: size, orbit: orbit) else { return .empty }
        let drawn: BinaryGardensSceneSnapshot = G.drawnSnapshot(snapshot)
        let cast: SIMD2<Double>? = planePoint(point, size: size, orbit: orbit)
        if let c = cast {
            if onActionsBar(c, drawn) { return .empty }
            var row: Int = drawn.worlds.count - 1
            while row >= 0 {
                if abs(c.y - G.gaugeY(row)) <= G.plateHalf && c.x >= G.plateLeft && c.x <= G.plateRight {
                    return .gauge(row)
                }
                row -= 1
            }
        }
        let order: [BinaryGardensElement] = G.paintOrder(drawn, eye: view.eye)
        var index: Int = order.count - 1
        while index >= 0 {
            let element: BinaryGardensElement = order[index]
            index -= 1
            switch element.kind {
            case .star:
                let star: Int = element.item
                if let gap = pipRowDistance(point, star: star, size: size, snapshot: drawn, camera: view),
                   gap <= markerAllowance {
                    return .pips(star)
                }
                if hits(point, centre: G.starCentre(star, drawn), extent: G.starRadius(star, drawn), size: size,
                        camera: view) {
                    return .star(star)
                }
            case .world:
                let world: Int = element.item
                if hits(point, centre: G.worldCentre(world, drawn), extent: G.worldRadius, size: size, camera: view) {
                    return .world(world)
                }
            default:
                continue
            }
        }
        var ring: Int = drawn.ringRadii.count - 1
        while ring >= 0 {
            if let gap = ringDistance(point, ring: ring, size: size, snapshot: drawn, camera: view),
               gap <= markerAllowance {
                return .ring(ring)
            }
            ring -= 1
        }
        if drawn.maxTilt > 0, let gap = dialDistance(point, size: size, snapshot: drawn, camera: view),
           gap <= markerAllowance {
            return .dial
        }
        if let c = cast, (c.x * c.x + c.y * c.y).squareRoot() <= G.discRadius { return .disc }
        return .empty
    }

    /// The point of the plane z = 0 under view point `point` (origin top left, y down) of a view of `size` points seen
    /// from the camera of `orbit` (clamped), in world units (x, y): the ray from the eye through the point cast onto
    /// the plane. Nil for a non-finite point, an unusable size, or a ray that does not meet the plane in front of the
    /// eye.
    public static func planePoint(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                  orbit: BinaryGardensViewOrbit) -> SIMD2<Double>? {
        typealias G = BinaryGardensSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(size: size, orbit: orbit) else { return nil }
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(view)
        let tanHalf: Double = tan(view.fovY / 2)
        let x: Double = (2 * point.x / size.x - 1) * tanHalf * view.aspect
        let y: Double = (1 - 2 * point.y / size.y) * tanHalf
        let ray: SIMD3<Double> = basis.forward + basis.right * x + basis.up * y
        guard ray.z.isFinite, ray.z < 0 else { return nil }
        let t: Double = -view.eye.z / ray.z
        guard t.isFinite, t > 0 else { return nil }
        let hit: SIMD3<Double> = view.eye + ray * t
        guard hit.x.isFinite, hit.y.isFinite else { return nil }
        return SIMD2(hit.x, hit.y)
    }

    /// Star `star`'s projected orbit tangent in view points in a view of `size` points showing `snapshot` from the
    /// camera of `orbit`: the view point of its ring vertex at table step s + 1 minus that at s − 1, s =
    /// ``BinaryGardensSceneSnapshot/starStep(_:tick:)`` at the shown tick, on its ring at the current tilt. Nil for a
    /// star or ring the snapshot lacks, an unusable size or a vertex behind the eye.
    public static func tangent(star: Int, size: SIMD2<Double>, snapshot: BinaryGardensSceneSnapshot,
                               orbit: BinaryGardensViewOrbit) -> SIMD2<Double>? {
        typealias G = BinaryGardensSceneGeometry
        guard let view = camera(size: size, orbit: orbit), let radius = ringRadius(star, snapshot) else { return nil }
        let step: Int = snapshot.starStep(star, tick: snapshot.shownTick)
        let tilt: Int = snapshot.arrangement.tilt
        let k: Double = snapshot.fitScale
        guard let ahead = viewPoint(G.ringVertex(radius: radius, step: step + 1, tilt: tilt, scale: k), size: size,
                                    camera: view),
              let behind = viewPoint(G.ringVertex(radius: radius, step: step - 1, tilt: tilt, scale: k), size: size,
                                     camera: view) else { return nil }
        return ahead - behind
    }

    /// The mode of a drag of star `star` that travelled `travel` view points (finger − touch-down point), in a view of
    /// `size` points showing `snapshot` from the camera of `orbit`: the star's freedoms first (only its ring
    /// adjustable: ring; only its phase: phase; neither: nil, the drag explains and sends nothing); otherwise phase when
    /// the travel's component along the projected tangent û (``tangent(star:size:snapshot:orbit:)``) is strictly
    /// greater than its component across it, else ring; ring for a tangent shorter than ``tangentFloor``, a missing
    /// tangent or a non-finite travel.
    public static func dragMode(travel: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                snapshot: BinaryGardensSceneSnapshot,
                                orbit: BinaryGardensViewOrbit) -> BinaryGardensStarDragMode? {
        let freedom: BinaryGardensStarFreedom = snapshot.freedom(star)
        switch (freedom.ring, freedom.phase) {
        case (false, false): return nil
        case (true, false): return .ring
        case (false, true): return .phase
        case (true, true): break
        }
        guard travel.x.isFinite, travel.y.isFinite,
              let u = tangent(star: star, size: size, snapshot: snapshot, orbit: orbit) else { return .ring }
        let length: Double = (u.x * u.x + u.y * u.y).squareRoot()
        guard length.isFinite, length >= tangentFloor else { return .ring }
        let unitTangent: SIMD2<Double> = u / length
        let signed: Double = travel.x * unitTangent.x + travel.y * unitTangent.y
        let acrossVector: SIMD2<Double> = travel - unitTangent * signed
        let along: Double = abs(signed)
        let across: Double = (acrossVector.x * acrossVector.x + acrossVector.y * acrossVector.y).squareRoot()
        return along > across ? .phase : .ring
    }

    /// The ring index a ring drag of star `star` reads at `point`: the ring whose vertex at the star's drawn table step
    /// (radius k · ρᵢ, the current tilt) projects nearest the point (lower index on ties); the star's current ring for
    /// unusable input or when no vertex projects.
    public static func ringTarget(_ point: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                  snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int {
        typealias G = BinaryGardensSceneGeometry
        let rings: [Int] = snapshot.arrangement.rings
        let current: Int = rings.indices.contains(star) ? rings[star] : 0
        guard point.x.isFinite, point.y.isFinite, (0..<2).contains(star),
              let view = camera(size: size, orbit: orbit) else { return current }
        let step: Int = snapshot.starStep(star, tick: snapshot.shownTick)
        var best: Int = current
        var bestDistance: Double = Double.infinity
        for (index, radius) in snapshot.ringRadii.enumerated() {
            let vertex: SIMD3<Double> = G.ringVertex(radius: radius, step: step, tilt: snapshot.arrangement.tilt,
                                                     scale: snapshot.fitScale)
            guard let p = viewPoint(vertex, size: size, camera: view) else { continue }
            let d: Double = distance(point, p)
            if d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        return best
    }

    /// The grid phase a phase drag of star `star` reads at `point`: the phase p ∈ {0, g, 2g, …, 48 − g} whose drawn
    /// position at the shown tick (table step (p + ω · t) mod 48 on the star's ring at the current tilt) projects
    /// nearest the point (lower p on ties); the star's current phase for unusable input or when no vertex projects.
    public static func phaseTarget(_ point: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                   snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int {
        typealias G = BinaryGardensSceneGeometry
        let phases: [Int] = snapshot.arrangement.phases
        let current: Int = phases.indices.contains(star) ? phases[star] : 0
        guard point.x.isFinite, point.y.isFinite, let radius = ringRadius(star, snapshot),
              let view = camera(size: size, orbit: orbit) else { return current }
        let grid: Int = max(snapshot.phaseStep, 1)
        var best: Int = current
        var bestDistance: Double = Double.infinity
        for p in stride(from: 0, to: BinaryGardensSky.cycle, by: grid) {
            let step: Int = BinaryGardensSky.phase(p, speed: snapshot.starSpeed, tick: snapshot.shownTick)
            let vertex: SIMD3<Double> = G.ringVertex(radius: radius, step: step, tilt: snapshot.arrangement.tilt,
                                                     scale: snapshot.fitScale)
            guard let v = viewPoint(vertex, size: size, camera: view) else { continue }
            let d: Double = distance(point, v)
            if d < bestDistance {
                best = p
                bestDistance = d
            }
        }
        return best
    }

    /// The luminosity index of star `star`'s pip whose projected centre (the pips facing the drawn eye) is nearest
    /// `point` (lower index on ties); the star's current luminosity for unusable input.
    public static func nearestPip(_ point: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                  snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int {
        let lums: [Int] = snapshot.arrangement.luminosities
        let current: Int = lums.indices.contains(star) ? lums[star] : 0
        guard point.x.isFinite, point.y.isFinite, (0..<2).contains(star),
              let view = camera(size: size, orbit: orbit) else { return current }
        let pips: [(centre: SIMD3<Double>, lit: Bool)] = BinaryGardensSceneGeometry.luminosityPips(star, snapshot,
                                                                                                    eye: view.eye)
        var best: Int = current
        var bestDistance: Double = Double.infinity
        for (index, pip) in pips.enumerated() {
            guard let p = viewPoint(pip.centre, size: size, camera: view) else { continue }
            let d: Double = distance(point, p)
            if d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        return best
    }

    /// The tilt step of the dial pip whose projected centre is nearest `point` (lower step on ties); the current tilt
    /// for unusable input or a level without a dial (T_max = 0).
    public static func nearestTiltPip(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                      snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int {
        let current: Int = snapshot.arrangement.tilt
        guard point.x.isFinite, point.y.isFinite, snapshot.maxTilt > 0,
              let view = camera(size: size, orbit: orbit) else { return current }
        var best: Int = current
        var bestDistance: Double = Double.infinity
        for step in 0...snapshot.maxTilt {
            guard let p = viewPoint(BinaryGardensSceneGeometry.tiltPipCentre(step), size: size, camera: view) else {
                continue
            }
            let d: Double = distance(point, p)
            if d < bestDistance {
                best = step
                bestDistance = d
            }
        }
        return best
    }

    /// The value a luminosity or tilt drag reads after horizontal travel `travel` (view points, right positive) from
    /// `start`: clamp(start + round(travel / ``stepTravel``), 0, upper), halves away from zero (right raises); `start`
    /// itself (clamped) for a non-finite travel.
    public static func stepValue(start: Int, travel: Double, upper: Int) -> Int {
        let top: Int = max(upper, 0)
        let base: Int = min(max(start, 0), top)
        guard travel.isFinite else { return base }
        let steps: Double = (travel / stepTravel).rounded(.toNearestOrAwayFromZero)
        let bounded: Double = min(max(steps, -Double(top + 1)), Double(top + 1))
        return min(max(base + Int(bounded), 0), top)
    }

    /// The x in world units of the finger cast onto the plane z = 0 (``planePoint(_:size:orbit:)``); nil for unusable
    /// input.
    public static func gaugeX(_ point: SIMD2<Double>, size: SIMD2<Double>, orbit: BinaryGardensViewOrbit) -> Double? {
        planePoint(point, size: size, orbit: orbit)?.x
    }

    /// The tick 1 … 48 under the finger on a gauge row: clamp(⌊(x + 0.9) / (1.8 / 48)⌋ + 1, 1, 48) for the cast x
    /// (``gaugeX(_:size:orbit:)``) clamped to the cells −0.9 … 0.9 (so the plate's left margin reads 1 and the bloom
    /// meter 48); nil for unusable input.
    public static func gaugeTick(_ point: SIMD2<Double>, size: SIMD2<Double>, orbit: BinaryGardensViewOrbit) -> Int? {
        typealias G = BinaryGardensSceneGeometry
        guard let x = gaugeX(point, size: size, orbit: orbit) else { return nil }
        let clamped: Double = min(max(x, G.cellsStart), G.cellsEnd)
        let column: Int = Int(((clamped - G.cellsStart) / G.cellPitch).rounded(.down)) + 1
        return min(max(column, 1), BinaryGardensSky.cycle)
    }

    // MARK: Distances

    /// The distance in view points from `point` to star `star`'s projected luminosity pip row (the segment from its
    /// first to its last pip centre, facing `camera`'s eye; a point for a single level); nil when a pip does not project
    /// or the level has no luminosity level.
    public static func pipRowDistance(_ point: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                      snapshot: BinaryGardensSceneSnapshot, camera: BinaryGardensCamera) -> Double? {
        let pips: [(centre: SIMD3<Double>, lit: Bool)] = BinaryGardensSceneGeometry.luminosityPips(star, snapshot,
                                                                                                    eye: camera.eye)
        guard let first = pips.first, let last = pips.last,
              let a = viewPoint(first.centre, size: size, camera: camera),
              let b = viewPoint(last.centre, size: size, camera: camera) else { return nil }
        return segmentDistance(point, a, b)
    }

    /// The distance in view points from `point` to ring `ring`'s projected 48-gon at the snapshot's tilt (segments with
    /// an end behind the eye skipped); nil when no segment projects.
    public static func ringDistance(_ point: SIMD2<Double>, ring: Int, size: SIMD2<Double>,
                                    snapshot: BinaryGardensSceneSnapshot, camera: BinaryGardensCamera) -> Double? {
        typealias G = BinaryGardensSceneGeometry
        guard snapshot.ringRadii.indices.contains(ring) else { return nil }
        let radius: Int = snapshot.ringRadii[ring]
        var projected: [SIMD2<Double>?] = []
        for step in 0..<BinaryGardensSky.cycle {
            let vertex: SIMD3<Double> = G.ringVertex(radius: radius, step: step, tilt: snapshot.arrangement.tilt,
                                                     scale: snapshot.fitScale)
            projected.append(viewPoint(vertex, size: size, camera: camera))
        }
        var best: Double? = nil
        for step in 0..<BinaryGardensSky.cycle {
            guard let a = projected[step], let b = projected[(step + 1) % BinaryGardensSky.cycle] else { continue }
            let d: Double = segmentDistance(point, a, b)
            if best == nil || d < best! { best = d }
        }
        return best
    }

    /// The distance in view points from `point` to the projected tilt dial (the segment from pip 0 to pip T_max); nil
    /// when an end does not project.
    public static func dialDistance(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                    snapshot: BinaryGardensSceneSnapshot, camera: BinaryGardensCamera) -> Double? {
        typealias G = BinaryGardensSceneGeometry
        guard let a = viewPoint(G.tiltPipCentre(0), size: size, camera: camera),
              let b = viewPoint(G.tiltPipCentre(max(snapshot.maxTilt, 0)), size: size, camera: camera) else {
            return nil
        }
        return segmentDistance(point, a, b)
    }

    // MARK: Internals

    /// Whether the cast point `cast` lies inside an actions bar's rectangle of `snapshot`.
    static func onActionsBar(_ cast: SIMD2<Double>, _ snapshot: BinaryGardensSceneSnapshot) -> Bool {
        typealias G = BinaryGardensSceneGeometry
        guard snapshot.budget > 0, abs(cast.y - G.actionsY(snapshot)) <= G.actionsHeight / 2 else { return false }
        let half: Double = G.barFill * G.actionsSlot(snapshot) / 2
        for bar in 0..<snapshot.budget where abs(cast.x - G.actionsBar(bar, snapshot).x) <= half { return true }
        return false
    }

    /// Star `star`'s ring radius in `snapshot`; nil for a star or ring it lacks.
    static func ringRadius(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot) -> Int? {
        let rings: [Int] = snapshot.arrangement.rings
        guard (0..<2).contains(star), rings.indices.contains(star),
              snapshot.ringRadii.indices.contains(rings[star]) else { return nil }
        return snapshot.ringRadii[rings[star]]
    }

    /// Whether `point` lies within the projected `extent` of `centre` grown by ``markerAllowance`` points.
    static func hits(_ point: SIMD2<Double>, centre: SIMD3<Double>, extent: Double, size: SIMD2<Double>,
                     camera: BinaryGardensCamera) -> Bool {
        guard let c = viewPoint(centre, size: size, camera: camera),
              let reach = projectedExtent(extent, at: centre, size: size, camera: camera) else { return false }
        return distance(point, c) <= reach + markerAllowance
    }

    /// Whether `size` is finite and positive in both components.
    static func usable(_ size: SIMD2<Double>) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }

    /// The distance between view points `a` and `b`.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The distance from view point `p` to the segment `a` → `b` (to `a` for a segment of length 0).
    static func segmentDistance(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = b - a
        let length2: Double = d.x * d.x + d.y * d.y
        guard length2 > 0 else { return distance(p, a) }
        let w: SIMD2<Double> = p - a
        let t: Double = min(max((w.x * d.x + w.y * d.y) / length2, 0), 1)
        return distance(p, a + d * t)
    }
}
