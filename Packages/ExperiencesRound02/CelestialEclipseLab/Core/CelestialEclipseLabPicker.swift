// CelestialEclipseLabPicker — feature 464 (R02-G17-04) T-R02G1704-002 (FR-R02G1704-003, 005; SC-R02G1704-001, 004;
// clarifications Q1, Q3, Q4). Analytic, deterministic picking of a touch in the drawn Celestial Eclipse Lab sky.
// Everything is projected through the drawn camera (`CelestialEclipseLabSceneGeometry.camera(_:aspect:orbit:)` with
// the view's aspect width / height) into view points (origin top left, x right, y down; the size is the view's size in
// points):
//   - a body is hit when the touch lies within its projected disc radius — r · s converted to view points at the
//     body's depth along the view axis, r · s / (depth · tan(fovY / 2)) · height / 2 — grown by
//     ``CelestialEclipseLabPicker/bodyAllowance`` (8) points; of several hits the front-most wins: the body the
//     painter's order (`CelestialEclipseLabSceneGeometry.paintOrder(_:camera:)`) draws last. Bodies are picked where
//     they are drawn (their kernel positions at the shown tick), never at a ghost;
//   - else the time dial: the bounding box of the projected timeline strip ends (ticks 0 and horizon − 1) and the
//     projected ends of every window bracket, grown by 8 points;
//   - anything else (rings, halos, shadows, marks outside the box, bars, backdrop) is empty space, as is unusable input
// (a non-finite point, a size that is not finite and positive). The dial's tick is the tick whose projected place on
// the strip is nearest to the touch (lower on ties; under perspective the ticks are not evenly spaced on screen, so
// this replaces the clarified linear fraction). The ring offset of a drag is the phase p (0 … period − 1) whose
// position of the body at the shown tick, orbit[(tick + p) mod period] mapped by w (`ringPosition(_:offset:_:)`),
// projects nearest to the touch (ties to the lower p). Presentation only: the picker reads the drawn snapshot and the
// orbit and never changes the kernel. Modelled on feature 454's `StarlitCartouchePicker`.
import Foundation

/// What a touch picked in the Celestial Eclipse Lab sky (clarification Q1).
public enum CelestialEclipseLabPick: Sendable, Equatable {
    /// Body `index`: the front-most body whose projected disc radius, grown by
    /// ``CelestialEclipseLabPicker/bodyAllowance`` points, holds the touch.
    case body(Int)
    /// The time dial: no body is hit and the touch lies in the projected strip-and-brackets box grown by
    /// ``CelestialEclipseLabPicker/bodyAllowance`` points.
    case dial
    /// Nothing: unusable input, or no body and not the dial.
    case empty
}

/// The analytic picker of the Celestial Eclipse Lab sky: bodies by their projected discs (front-most first), then the
/// time dial, each projected through the drawn camera into view points; plus the dial's tick and a drag's ring offset.
public enum CelestialEclipseLabPicker {
    /// How many view points a body's target (and the dial's box) reaches beyond its projected extent, 8.
    public static let bodyAllowance: Double = 8

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``CelestialEclipseLabSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: CelestialEclipseLabCamera) -> SIMD2<Double>? {
        guard usable(size), let v = CelestialEclipseLabSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The radius in view points of a camera-facing circle of world radius `radius` about `centre` seen through
    /// `camera` in a view of `size` points: radius / (depth · tan(fovY / 2)) · height / 2, depth the centre's distance
    /// along the view axis. Nil when the centre is not in front of the eye or the size is unusable.
    public static func projectedRadius(_ radius: Double, at centre: SIMD3<Double>, size: SIMD2<Double>,
                                       camera: CelestialEclipseLabCamera) -> Double? {
        typealias G = CelestialEclipseLabSceneGeometry
        guard usable(size) else { return nil }
        let forward: SIMD3<Double> = G.viewBasis(camera).forward
        let depth: Double = G.dot(centre - camera.eye, forward)
        let tanHalf: Double = tan(camera.fovY / 2)
        guard depth.isFinite, depth > 0, tanHalf.isFinite, tanHalf > 0 else { return nil }
        let r: Double = radius / (depth * tanHalf) * size.y / 2
        return r.isFinite ? r : nil
    }

    /// The drawn camera of a view of `size` points showing `snapshot` from `orbit` (clamped): aspect width / height.
    /// Nil for a size that is not finite and positive.
    public static func camera(size: SIMD2<Double>, snapshot: CelestialEclipseLabSceneSnapshot,
                              orbit: CelestialEclipseLabOrbit) -> CelestialEclipseLabCamera? {
        guard usable(size) else { return nil }
        return CelestialEclipseLabSceneGeometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: the front-most body (drawn last in
    /// ``CelestialEclipseLabSceneGeometry/paintOrder(_:camera:)``) whose projected disc radius r · s grown by
    /// ``bodyAllowance`` points holds the touch, as ``CelestialEclipseLabPick/body(_:)``; else
    /// ``CelestialEclipseLabPick/dial`` when the touch lies in the projected strip-and-brackets box
    /// (``dialBox(size:snapshot:camera:)``) grown by ``bodyAllowance`` points; else ``CelestialEclipseLabPick/empty``
    /// (also for a non-finite point or a size that is not finite and positive). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: CelestialEclipseLabSceneSnapshot,
                            orbit: CelestialEclipseLabOrbit) -> CelestialEclipseLabPick {
        typealias G = CelestialEclipseLabSceneGeometry
        guard point.x.isFinite, point.y.isFinite,
              let view = Self.camera(size: size, snapshot: snapshot, orbit: orbit) else { return .empty }
        let order: [CelestialEclipseLabElement] = G.paintOrder(snapshot, camera: view)
        for element in order.reversed() where element.part == .body {
            guard let centre = viewPoint(element.centre, size: size, camera: view),
                  let radius = projectedRadius(G.bodyRadius(element.item, snapshot), at: element.centre, size: size,
                                               camera: view)
            else { continue }
            if distance(point, centre) <= radius + bodyAllowance { return .body(element.item) }
        }
        if let box = dialBox(size: size, snapshot: snapshot, camera: view), point.x >= box.low.x - bodyAllowance,
           point.x <= box.high.x + bodyAllowance, point.y >= box.low.y - bodyAllowance,
           point.y <= box.high.y + bodyAllowance {
            return .dial
        }
        return .empty
    }

    /// The bounding box (lower and upper corner, view points) of the projected timeline strip ends
    /// (``CelestialEclipseLabSceneGeometry/tickPosition(_:_:)`` of ticks 0 and horizon − 1) and the projected ends of
    /// every target window's bracket (``CelestialEclipseLabSceneGeometry/bracketEnds(_:_:)`` on the brackets' line);
    /// nil when a point is behind the eye or the size is unusable. Not grown by the allowance.
    public static func dialBox(size: SIMD2<Double>, snapshot: CelestialEclipseLabSceneSnapshot,
                               camera: CelestialEclipseLabCamera) -> (low: SIMD2<Double>, high: SIMD2<Double>)? {
        typealias G = CelestialEclipseLabSceneGeometry
        guard usable(size) else { return nil }
        var points: [SIMD3<Double>] = [G.tickPosition(0, snapshot), G.tickPosition(snapshot.horizon - 1, snapshot)]
        for index in snapshot.target.indices {
            let ends: (Double, Double) = G.bracketEnds(index, snapshot)
            points.append(SIMD3(ends.0, G.bracketY, G.gaugeZ))
            points.append(SIMD3(ends.1, G.bracketY, G.gaugeZ))
        }
        var low: SIMD2<Double> = SIMD2(Double.infinity, Double.infinity)
        var high: SIMD2<Double> = SIMD2(-Double.infinity, -Double.infinity)
        for world in points {
            guard let p = viewPoint(world, size: size, camera: camera) else { return nil }
            low = SIMD2(min(low.x, p.x), min(low.y, p.y))
            high = SIMD2(max(high.x, p.x), max(high.y, p.y))
        }
        return (low, high)
    }

    /// The tick the time dial reads at `point` (view points) in a view of `size` points showing `snapshot` from the
    /// camera of `orbit` (clamped): the tick 0 … horizon − 1 whose projected place on the strip
    /// (``CelestialEclipseLabSceneGeometry/tickPosition(_:_:)``) is nearest to the point, the lower tick on ties. The
    /// snapshot's shown tick for unusable input (a non-finite point, an
    /// unusable size, a strip end behind the eye, coincident ends).
    public static func dialTick(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                snapshot: CelestialEclipseLabSceneSnapshot,
                                orbit: CelestialEclipseLabOrbit) -> Int {
        typealias G = CelestialEclipseLabSceneGeometry
        let last: Int = max(snapshot.horizon - 1, 0)
        let fallback: Int = min(max(snapshot.shownTick, 0), last)
        guard point.x.isFinite, point.y.isFinite,
              let view = Self.camera(size: size, snapshot: snapshot, orbit: orbit),
              let a = viewPoint(G.tickPosition(0, snapshot), size: size, camera: view),
              let b = viewPoint(G.tickPosition(last, snapshot), size: size, camera: view) else { return fallback }
        _ = (a, b)
        // The tick whose projected position is nearest (lower on ties): under perspective the ticks are not evenly
        // spaced on screen, so a linear fraction along the strip would miss by one.
        var best: Int = fallback
        var bestDistance: Double = Double.infinity
        for tick in 0...last {
            guard let q = viewPoint(G.tickPosition(tick, snapshot), size: size, camera: view) else { continue }
            let e: SIMD2<Double> = point - q
            let d2: Double = e.x * e.x + e.y * e.y
            if d2 < bestDistance {
                best = tick
                bestDistance = d2
            }
        }
        return best
    }

    /// The ring offset a drag of body `body` reads at `point` (view points) in a view of `size` points showing
    /// `snapshot` from the camera of `orbit` (clamped): the phase p in 0 … period − 1 whose
    /// ``CelestialEclipseLabSceneGeometry/ringPosition(_:offset:_:)`` (the body's orbit position at the shown tick with
    /// phase p) projects nearest to the point, the lower p on ties. 0 for a body the level does not have; the body's
    /// current phase for unusable input (a non-finite point, an unusable size, every position behind the eye).
    public static func ringOffset(_ point: SIMD2<Double>, body: Int, size: SIMD2<Double>,
                                  snapshot: CelestialEclipseLabSceneSnapshot,
                                  orbit: CelestialEclipseLabOrbit) -> Int {
        typealias G = CelestialEclipseLabSceneGeometry
        guard snapshot.bodies.indices.contains(body) else { return 0 }
        let period: Int = snapshot.bodies[body].period
        let current: Int = snapshot.phases.indices.contains(body) ? snapshot.phases[body] : 0
        guard period > 0, point.x.isFinite, point.y.isFinite,
              let view = Self.camera(size: size, snapshot: snapshot, orbit: orbit) else { return current }
        var best: Int = current
        var bestDistance: Double = Double.infinity
        for p in 0..<period {
            guard let q = viewPoint(G.ringPosition(body, offset: p, snapshot), size: size, camera: view) else {
                continue
            }
            let e: Double = distance(point, q)
            if e < bestDistance {
                bestDistance = e
                best = p
            }
        }
        return best
    }

    // MARK: Internals

    /// Whether `size` is finite and positive in both components.
    static func usable(_ size: SIMD2<Double>) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }

    /// The distance between view points `a` and `b`.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }
}
