// EclipseGeometry — feature 215 (R02-F15) T-R02F15-005 (FR-R02F15-006; SC-R02F15-005; clarification Q4; research
// R8). An observer projects a spherical light source and a spherical occluder onto the sky: at distances dₛ, dₒ the
// angular radii are αₛ = asin(Rₛ/dₛ), αₒ = asin(Rₒ/dₒ), and the separation θ of the two directions a, b is
// atan2(|a × b|, a · b), accurate at small angles. With an optional ground sphere (the observer's own body, centre g,
// radius R_g, observer height h = |o − g| ≥ R_g) the horizon dips by δ = acos(R_g/h) below the local horizontal; the
// source is hidden when its whole disk lies below that horizon, ε + αₛ < −δ, where ε is the elevation of the source's
// centre above the local horizontal (up = (o − g)/h). Otherwise the event is none when the occluder is not nearer
// (dₒ ≥ dₛ) or the disks do not overlap (θ ≥ αₛ + αₒ, touching included); total when αₒ ≥ αₛ and θ ≤ αₒ − αₛ;
// annular when αₒ < αₛ and θ ≤ αₛ − αₒ; partial otherwise. The covered fraction is the planar disk overlap of radii
// αₛ, αₒ at distance θ over the source disk (``DiskOverlap``): 0 for none, 1 for total and hidden. Pure and
// deterministic; bodies are uniform spheres (no limb darkening).
import Foundation

/// A spherical body seen by an eclipse observer: a centre and a radius in the caller's length unit.
///
/// The radius is checked by ``EclipseGeometry/classify(observer:source:occluder:ground:)``, which refuses a body
/// whose centre is not finite or whose radius is not finite and positive.
public struct EclipseBody: Sendable, Equatable {
    /// The centre of the sphere.
    public let center: Vec3
    /// The radius of the sphere; must be finite and > 0 for classification.
    public let radius: Double

    /// A body with the given centre and radius (validated when classified, not here).
    public init(center: Vec3, radius: Double) {
        self.center = center
        self.radius = radius
    }
}

/// What an observer sees of a light source with an occluder in front of it.
public enum EclipseClass: String, Sendable, Codable, CaseIterable {
    /// The occluder covers no part of the source (or is not nearer than it).
    case none
    /// The occluder covers part of the source, and the source's rim is not wholly visible around it.
    case partial
    /// The occluder lies wholly inside the source's disk, leaving a ring.
    case annular
    /// The occluder covers the whole source disk.
    case total
    /// The whole source disk is below the observer's horizon on the ground sphere.
    case hidden
}

/// The result of an eclipse classification: the projected disks, their separation, the covered fraction and the class.
public struct EclipseVerdict: Sendable, Equatable {
    /// The angular radius αₛ of the source, in radians.
    public let sourceAngularRadius: Double
    /// The angular radius αₒ of the occluder, in radians.
    public let occluderAngularRadius: Double
    /// The angle θ between the directions to the source and the occluder, in radians (0 … π).
    public let separation: Double
    /// The fraction of the source disk covered, in [0, 1]; 1 for ``EclipseClass/total`` and ``EclipseClass/hidden``.
    public let coveredFraction: Double
    /// The classified event.
    public let eclipseClass: EclipseClass

    /// A verdict with the given members.
    public init(sourceAngularRadius: Double, occluderAngularRadius: Double, separation: Double,
                coveredFraction: Double, eclipseClass: EclipseClass) {
        self.sourceAngularRadius = sourceAngularRadius
        self.occluderAngularRadius = occluderAngularRadius
        self.separation = separation
        self.coveredFraction = coveredFraction
        self.eclipseClass = eclipseClass
    }
}

/// Projects a source and an occluder onto an observer's sky and classifies the eclipse (clarification Q4).
public enum EclipseGeometry {
    /// Classifies what `observer` sees of `source` with `occluder` in the way, optionally standing on `ground`.
    ///
    /// - Parameters:
    ///   - observer: The observer's position.
    ///   - source: The light source.
    ///   - occluder: The occluding body.
    ///   - ground: The observer's own body, whose horizon can hide the source; the observer may stand on its surface.
    /// - Returns: The verdict, which always reports αₛ, αₒ and θ.
    /// - Throws: ``OrbitError/invalidDisk`` when a position is not finite or a radius is not finite and positive;
    ///   ``OrbitError/observerInside`` when the observer lies strictly inside the source, the occluder or the ground.
    public static func classify(observer: Vec3, source: EclipseBody, occluder: EclipseBody,
                                ground: EclipseBody? = nil) throws(OrbitError) -> EclipseVerdict {
        guard observer.isFinite, valid(source), valid(occluder) else { throw .invalidDisk }
        if let ground, !valid(ground) { throw .invalidDisk }
        let toSource = source.center - observer
        let toOccluder = occluder.center - observer
        let ds = toSource.length
        let dOcc = toOccluder.length
        guard ds.isFinite, dOcc.isFinite else { throw .invalidDisk }
        if ds < source.radius || dOcc < occluder.radius { throw .observerInside }
        var height = 0.0
        if let ground {
            height = (observer - ground.center).length
            guard height.isFinite else { throw .invalidDisk }
            if height < ground.radius { throw .observerInside }
        }
        let alphaS = asin(min(1, source.radius / ds))
        let alphaO = asin(min(1, occluder.radius / dOcc))
        let dirS = toSource / ds
        let dirO = toOccluder / dOcc
        let theta = atan2(dirS.cross(dirO).length, dirS.dot(dirO))

        if let ground {
            let up = (observer - ground.center) / height
            let dip = acos(min(1, ground.radius / height))
            let elevation = asin(min(1, max(-1, dirS.dot(up))))
            if elevation + alphaS < -dip {
                return EclipseVerdict(sourceAngularRadius: alphaS, occluderAngularRadius: alphaO, separation: theta,
                                      coveredFraction: 1, eclipseClass: .hidden)
            }
        }
        if dOcc >= ds || theta >= alphaS + alphaO {
            return EclipseVerdict(sourceAngularRadius: alphaS, occluderAngularRadius: alphaO, separation: theta,
                                  coveredFraction: 0, eclipseClass: .none)
        }
        let eclipseClass: EclipseClass
        if alphaO >= alphaS && theta <= alphaO - alphaS {
            eclipseClass = .total
        } else if alphaO < alphaS && theta <= alphaS - alphaO {
            eclipseClass = .annular
        } else {
            eclipseClass = .partial
        }
        let fraction: Double
        if eclipseClass == .total {
            fraction = 1
        } else {
            fraction = try DiskOverlap.coveredFraction(sourceRadius: alphaS, occluderRadius: alphaO, distance: theta)
        }
        return EclipseVerdict(sourceAngularRadius: alphaS, occluderAngularRadius: alphaO, separation: theta,
                              coveredFraction: fraction, eclipseClass: eclipseClass)
    }

    /// Whether a body has a finite centre and a finite, positive radius.
    private static func valid(_ body: EclipseBody) -> Bool {
        body.center.isFinite && body.radius.isFinite && body.radius > 0
    }
}
