// FractalCore — feature 193 (UA-F07) T-U07-024 (FR-U07-001 to FR-U07-004; research R1, R2; data-model section 2). The
// state of Fractal Explorer as an experience: the family, a size-independent framing (centre and span across the
// shorter side, VisualCoreMath `PlaneFraming`), the Julia seed, the iteration cap and escape radius, the palette and its
// animation, and a playing tour. Tours and palette animation advance in fixed steps, never with `systemUptime`.
//
// Differences from the standalone app (FR-U07-003):
//   1. The framing does not depend on the view's size: `pan` and `pinch` carry distances in units of the view's
//      shorter side (the presenter divides points by it), and the presenter derives the viewport from the drawable.
//   2. The precision limit uses fixed, conservative constants (23 mantissa bits, 3 pixels per point, a 1,024-point
//      shorter side) instead of the device's shader precision, so the state never depends on the device.
//   3. Tours and the palette animation advance by the fixed step of 1/120 s, not by `systemUptime` or the frame
//      delta; a tour's Reduce Motion is the value `tour.start` carries.
//   4. Go-to parsing stays in the controls; `goTo` carries numbers. Opening a bookmark is `bookmark.open` with its
//      values (and `radius` when it is not 2), because an action carries at most eight numbers.
//   5. The outcome `deep-zoom` (1,000× or more) gives the verification runner's completion scenario something to
//      reach; the standalone app had no outcome.
import Foundation
import FractalExplorerCore
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence

/// The state of Fractal Explorer. Codable; schema version 1.
public struct FractalCore: ExperienceCore, Codable, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a03.fractal-explorer"
    /// The palettes offered (`Bookmark.paletteIDs`).
    public static let paletteIDs = Bookmark.paletteIDs
    /// The largest span (plane units across the shorter side).
    public static let maxSpan = 1e6
    /// The zoom from which the outcome `deep-zoom` holds.
    public static let deepZoom = 1_000.0
    /// The palette animation's loop, as the standalone scene's clock (seconds).
    public static let paletteLoop = 86_400.0
    /// The constants of the device-independent precision limit (difference 2).
    public static let limitMantissaBits = 23
    public static let limitPixelsPerPoint = 3.0
    public static let limitShorterSide = 1_024.0

    /// The seed the state was prepared from.
    public private(set) var seed: UInt64
    /// Mandelbrot or Julia.
    public private(set) var mode: FractalMode
    /// The centre and the span across the shorter side.
    public private(set) var framing: PlaneFraming
    /// The Julia seed c.
    public private(set) var juliaSeed: Vec2
    /// Iterations per point (50…10,000, `CapControl`).
    public private(set) var cap: Int
    /// The escape radius (at least 2).
    public private(set) var radius: Double
    /// The palette's id.
    public private(set) var paletteID: String
    /// Whether the palette animates.
    public private(set) var animate: Bool
    /// The palette animation's time in seconds.
    public private(set) var paletteTime: Double
    /// The tour being played (index into `FractalTours.all`), or nil.
    public private(set) var tourIndex: Int?
    /// Where the tour started, with its Reduce Motion choice.
    public private(set) var tourStart: PlaneFraming?
    public private(set) var tourReduceMotion: Bool
    /// Seconds since the tour started.
    public private(set) var tourElapsed: Double
    /// Whether the tour still moves or holds.
    public private(set) var tourPlaying: Bool
    /// The last stop the tour reached (its caption is shown), or −1.
    public private(set) var tourStop: Int
    /// Whether the last change of the framing was stopped by the precision limit.
    public private(set) var limitReached: Bool

    // MARK: Contract

    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }

    public static var controls: [ExperienceControl] {
        let coordinate = -Bookmark.maxCoordinate...Bookmark.maxCoordinate
        let palettes = 0...Double(paletteIDs.count - 1)
        return [
            ExperienceControl(id: "mode", ranges: [0...1]),
            ExperienceControl(id: "pan", ranges: [-100...100, -100...100]),
            ExperienceControl(id: "pinch", ranges: [0.001...1_000, -100...100, -100...100]),
            ExperienceControl(id: "zoomIn"),
            ExperienceControl(id: "zoomOut"),
            ExperienceControl(id: "resetView"),
            ExperienceControl(id: "cap", ranges: [Double(CapControl.minimum)...Double(CapControl.maximum)]),
            ExperienceControl(id: "cap.up"),
            ExperienceControl(id: "cap.down"),
            ExperienceControl(id: "palette", ranges: [palettes]),
            ExperienceControl(id: "animate", ranges: [0...1]),
            ExperienceControl(id: "seed", ranges: [coordinate, coordinate]),
            ExperienceControl(id: "goTo", ranges: [coordinate, coordinate, 1e-9...GoToInput.maxZoom]),
            ExperienceControl(id: "tour.start", ranges: [0...Double(FractalTours.all.count - 1), 0...1]),
            ExperienceControl(id: "tour.stop"),
            ExperienceControl(id: "radius", ranges: [FractalMath.minimumRadius...1e6]),
            ExperienceControl(id: "bookmark.open", ranges: [0...1, coordinate, coordinate, 1e-15...maxSpan,
                                                           coordinate, coordinate,
                                                           Double(CapControl.minimum)...Double(CapControl.maximum),
                                                           palettes]),
        ]
    }

    public static func prepare(seed: UInt64) async throws -> FractalCore {
        try Task.checkCancellation()
        return FractalCore(seed: seed)
    }

    /// The standalone app's start: Mandelbrot at its default framing, the default seed, cap 200, R = 2, Sunset,
    /// animating.
    private init(seed: UInt64) {
        self.seed = seed
        mode = .mandelbrot
        framing = Self.defaultFraming(.mandelbrot)
        juliaSeed = FractalState.defaultSeed
        cap = CapControl.reference
        radius = FractalMath.minimumRadius
        paletteID = "sunset"
        animate = true
        paletteTime = 0
        tourIndex = nil
        tourStart = nil
        tourReduceMotion = false
        tourElapsed = 0
        tourPlaying = false
        tourStop = -1
        limitReached = false
    }

    /// The default framing of `mode`.
    public static func defaultFraming(_ mode: FractalMode) -> PlaneFraming {
        PlaneFraming(center: FractalState.defaultCenter(for: mode), span: FractalState.defaultWidth(for: mode))
    }

    /// One fixed step: the palette animates and a playing tour moves.
    public mutating func update(step: Int) {
        if animate { paletteTime = (paletteTime + Self.stepDuration).truncatingRemainder(dividingBy: Self.paletteLoop) }
        guard tourPlaying, let index = tourIndex, let start = tourStart else { return }
        tourElapsed += Self.stepDuration
        let state = FractalTours.all[index].timeline(from: start, reduceMotion: tourReduceMotion).state(at: tourElapsed)
        framing = clamped(state.framing)
        if state.phase != .flying { tourStop = state.stopIndex }
        if state.phase == .finished { tourPlaying = false }
    }

    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        switch action.control {
        case "mode":
            let next: FractalMode = v[0] >= 0.5 ? .julia : .mandelbrot
            guard next != mode else { return .rejected(.rule(code: "a03.same-mode")) }
            clearTour()
            mode = next
            move(to: Self.defaultFraming(next))
        case "pan":
            clearTour()
            move(to: PlaneFraming(center: Vec2(framing.center.x - v[0] * framing.span,
                                               framing.center.y + v[1] * framing.span), span: framing.span))
        case "pinch":
            clearTour()
            pinch(by: v[0], anchor: Vec2(v[1], v[2]))
        case "zoomIn":
            clearTour()
            pinch(by: 2, anchor: .zero)
        case "zoomOut":
            clearTour()
            pinch(by: 0.5, anchor: .zero)
        case "resetView":
            clearTour()
            move(to: Self.defaultFraming(mode))
        case "cap":
            cap = CapControl.clamp(Int(v[0].rounded()))
        case "cap.up":
            cap = CapControl.doubled(cap)
        case "cap.down":
            cap = CapControl.halved(cap)
        case "palette":
            paletteID = Self.paletteIDs[Int(v[0].rounded())]
        case "animate":
            animate = v[0] >= 0.5
        case "seed":
            juliaSeed = Vec2(v[0], v[1])
        case "goTo":
            clearTour()
            // `GoToTarget.framing(for:)`: span = the mode's default width ÷ zoom (its initializer is not public).
            move(to: PlaneFraming(center: Vec2(v[0], v[1]), span: FractalState.defaultWidth(for: mode) / v[2]))
        case "tour.start":
            let index = Int(v[0].rounded())
            if mode != FractalTours.all[index].mode {
                // As the standalone app: switching the family reframes to its default view first.
                mode = FractalTours.all[index].mode
                move(to: Self.defaultFraming(mode))
            }
            tourIndex = index
            tourStart = framing
            tourReduceMotion = v[1] >= 0.5
            tourElapsed = 0
            tourPlaying = true
            tourStop = -1
        case "tour.stop":
            guard tourPlaying else { return .rejected(.rule(code: "a03.no-tour")) }
            tourPlaying = false
        case "radius":
            radius = max(v[0], FractalMath.minimumRadius)
        case "bookmark.open":
            let opened = Bookmark(mode: v[0] >= 0.5 ? .julia : .mandelbrot,
                                  framing: PlaneFraming(center: Vec2(v[1], v[2]), span: v[3]),
                                  juliaSeed: Vec2(v[4], v[5]), iterationCap: Int(v[6].rounded()),
                                  escapeRadius: FractalMath.minimumRadius,
                                  paletteID: Self.paletteIDs[Int(v[7].rounded())],
                                  precision: PrecisionMode(mantissaBits: Self.limitMantissaBits, level: .reliable))
            guard let valid = opened.validated() else { return .rejected(.rule(code: "a03.invalid-bookmark")) }
            clearTour()
            mode = valid.mode
            juliaSeed = valid.juliaSeed
            cap = CapControl.clamp(valid.iterationCap)
            radius = valid.escapeRadius
            paletteID = valid.paletteID
            move(to: valid.framing)
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    public mutating func reset() {
        self = FractalCore(seed: seed)
    }

    /// `deep-zoom` once the view is magnified 1,000× or more.
    public var outcome: ExperienceOutcome? {
        zoom >= Self.deepZoom ? ExperienceOutcome(code: "deep-zoom") : nil
    }

    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(seed)
        builder.add(mode.rawValue)
        try builder.add(framing.center.x)
        try builder.add(framing.center.y)
        try builder.add(framing.span)
        try builder.add(juliaSeed.x)
        try builder.add(juliaSeed.y)
        builder.add(cap)
        try builder.add(radius)
        builder.add(paletteID)
        builder.add(animate)
        try builder.add(paletteTime)
        builder.add(tourIndex ?? -1)
        try builder.add(tourStart?.center.x ?? 0)
        try builder.add(tourStart?.center.y ?? 0)
        try builder.add(tourStart?.span ?? 0)
        builder.add(tourReduceMotion)
        try builder.add(tourElapsed)
        builder.add(tourPlaying)
        builder.add(tourStop)
        builder.add(limitReached)
    }

    // MARK: Derived values

    /// The magnification relative to the mode's default framing.
    public var zoom: Double { FractalState.defaultWidth(for: mode) / framing.span }

    /// The state the standalone app's scene and descriptions use, for a view of `size` points.
    public func state(size: Vec2) -> FractalState {
        var state = FractalState(mode: mode, size: size)
        state.viewport = framing.viewport(size: size)
        state.juliaSeed = juliaSeed
        state.iterationCap = cap
        state.escapeRadius = radius
        return state
    }

    /// The caption of the stop the tour reached, or nil.
    public var tourCaption: String? {
        guard let tourIndex, tourStop >= 0 else { return nil }
        let stops = FractalTours.all[tourIndex].stops
        return stops.indices.contains(tourStop) ? stops[tourStop].caption : nil
    }

    /// The smallest span the precision limit allows at `center` (difference 2).
    public static func minimumSpan(at center: Vec2) -> Double {
        let magnitude = max(abs(center.x), abs(center.y))
        let step = PrecisionAdvisor.minimumPixelStep(mantissaBits: limitMantissaBits, magnitude: magnitude)
        return max(step * limitPixelsPerPoint * limitShorterSide, 1e-15)
    }

    // MARK: Helpers

    /// Zooms by `scale` about `anchor`, given relative to the view's centre in units of its shorter side (y down):
    /// the plane point under the anchor stays under it, as `PlaneViewport.pinched` keeps it.
    private mutating func pinch(by scale: Double, anchor: Vec2) {
        let fixed = Vec2(framing.center.x + anchor.x * framing.span, framing.center.y - anchor.y * framing.span)
        let span = framing.span / scale
        move(to: PlaneFraming(center: Vec2(fixed.x - anchor.x * span, fixed.y + anchor.y * span), span: span))
    }

    /// Takes `next` within the precision limit and the largest span.
    private mutating func move(to next: PlaneFraming) {
        framing = clamped(next)
    }

    private mutating func clamped(_ next: PlaneFraming) -> PlaneFraming {
        let low = Self.minimumSpan(at: next.center)
        limitReached = next.span < low
        return PlaneFraming(center: next.center, span: min(max(next.span, low), Self.maxSpan))
    }

    /// An interaction ends a tour and its caption.
    private mutating func clearTour() {
        tourIndex = nil
        tourStart = nil
        tourElapsed = 0
        tourPlaying = false
        tourStop = -1
    }
}
