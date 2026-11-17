// SkyBlend — feature 153 (A21-P02) T-A21-203 (FR-A21-204; clarification Q3; data-model.md "Hue", "Blend";
// contracts/experience.md "Blend"). The shader inputs of a sky and the eased change between two of them:
//
//   - `SkyInputs`: what `aurora-sky.frag` draws besides the time, the level and the limit — a palette of five stops in
//     linear light (the sky, then one colour per ribbon slot, black for a slot beyond the ribbon count), the ribbon
//     count, the turbulence, the cloudiness and the star count. The five stops reproduce the shader's own colour
//     choice (`u_palette[1 + i % (count − 1)]` for ribbon i), so a scene draws the same picture through them. The
//     hue shift (`SkyHue`) turns every palette colour's hue first, in HSV of the sRGB colour.
//   - `SkyBlend`: from (the blend shown when the change began), to (the target) and the elapsed frame time; the
//     change takes ``SkyBlend/duration`` (1.5 s) of drawn-frame time, eased with smoothstep. During a change the
//     ribbon count is the larger of the two and a ribbon that only one side has fades from or to black (it adds no
//     light at black), so nothing pops; at the end the target's own inputs are drawn. A new change mid-way starts
//     from the current blend. `jump(to:)` (Reduce Motion, the first state) changes at once.
// The brightness limit is not blended: it applies to every frame, so the start, middle and end of a change are
// capped. Pure value types; no clock (the presenter passes frame deltas) and no GL.
import Foundation
import AuroraCore

/// The hue shift of a palette colour (feature 153).
enum SkyHue {
    /// `color` with its HSV hue turned by `turns` (a full turn is 1); saturation and value stay. A shift of 0, or a
    /// grey colour, returns the colour unchanged.
    static func shifted(_ color: SkyColor, turns: Double) -> SkyColor {
        guard turns.isFinite, turns != 0 else { return color }
        let r = color.red, g = color.green, b = color.blue
        let high = max(r, g, b), low = min(r, g, b)
        let chroma = high - low
        guard chroma > 0 else { return color }
        var hue: Double
        if high == r {
            hue = ((g - b) / chroma).truncatingRemainder(dividingBy: 6)
        } else if high == g {
            hue = (b - r) / chroma + 2
        } else {
            hue = (r - g) / chroma + 4
        }
        hue = hue / 6 + turns
        hue -= hue.rounded(.down)
        let sector = hue * 6
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch Int(sector.rounded(.down)) % 6 {
        case 0: (r1, g1, b1) = (chroma, x, 0)
        case 1: (r1, g1, b1) = (x, chroma, 0)
        case 2: (r1, g1, b1) = (0, chroma, x)
        case 3: (r1, g1, b1) = (0, x, chroma)
        case 4: (r1, g1, b1) = (x, 0, chroma)
        default: (r1, g1, b1) = (chroma, 0, x)
        }
        func unit(_ v: Double) -> Double { min(max(v + low, 0), 1) }
        return SkyColor(red: unit(r1), green: unit(g1), blue: unit(b1))
    }
}

/// The shader inputs of one sky (see the file header).
struct SkyInputs: Equatable, Sendable {
    /// The number of palette stops: the sky and four ribbon slots.
    static let stopCount = 5

    /// Five stops in linear light: the sky, then ribbon slots 0…3 (black beyond the ribbon count).
    var palette: [SIMD3<Float>]
    /// The ribbons drawn (1…4).
    var ribbons: Int
    /// How strongly the ribbons fold (0…1).
    var turbulence: Float
    /// How much of the sky the clouds cover (0…1).
    var cloudiness: Float
    /// The star count (0…400; rounded when drawn).
    var stars: Float

    /// The inputs as given.
    init(palette: [SIMD3<Float>], ribbons: Int, turbulence: Float, cloudiness: Float, stars: Float) {
        self.palette = palette
        self.ribbons = ribbons
        self.turbulence = turbulence
        self.cloudiness = cloudiness
        self.stars = stars
    }

    /// The inputs of `scene` with its palette's hue turned by `hue` turns.
    init(scene: SkyScene, hue: Double) {
        let colors = scene.palette.map { SkyShader.linear(SkyHue.shifted($0, turns: hue)) }
        let count = max(colors.count, 1)
        func stop(_ i: Int) -> SIMD3<Float> { colors.isEmpty ? .zero : colors[min(max(i, 0), count - 1)] }
        let ribbonColours = max(colors.count - 1, 1)
        var stops = [stop(0)]
        for slot in 0..<(Self.stopCount - 1) {
            stops.append(slot < scene.ribbons ? stop(1 + slot % ribbonColours) : .zero)
        }
        self.init(palette: stops, ribbons: scene.ribbons, turbulence: Float(scene.turbulence),
                  cloudiness: Float(scene.cloudiness), stars: Float(scene.stars))
    }

    /// The mix of `a` and `b` at `t` (0…1): every stop and value linearly; the ribbons the larger count before the
    /// end and `b`'s at `t` = 1.
    static func mix(_ a: SkyInputs, _ b: SkyInputs, _ t: Float) -> SkyInputs {
        if t >= 1 { return b }
        if t <= 0 { return SkyInputs(palette: a.palette, ribbons: max(a.ribbons, b.ribbons), turbulence: a.turbulence,
                                     cloudiness: a.cloudiness, stars: a.stars) }
        func lerp(_ x: Float, _ y: Float) -> Float { x + (y - x) * t }
        var stops: [SIMD3<Float>] = []
        for i in 0..<Self.stopCount {
            let x = i < a.palette.count ? a.palette[i] : .zero
            let y = i < b.palette.count ? b.palette[i] : .zero
            stops.append(x + (y - x) * t)
        }
        return SkyInputs(palette: stops, ribbons: max(a.ribbons, b.ribbons), turbulence: lerp(a.turbulence, b.turbulence),
                         cloudiness: lerp(a.cloudiness, b.cloudiness), stars: lerp(a.stars, b.stars))
    }

    /// The uniforms of these inputs at `phase` (0…1), quality `level` and brightness `limit`.
    func uniforms(phase: Double, level: Int, limit: Double) -> SkyUniforms {
        SkyUniforms(palette: palette, ribbons: ribbons, turbulence: turbulence, cloudiness: cloudiness,
                    stars: Int(stars.rounded()), phase: Float(phase), octaves: SkyShader.octaves(forLevel: level),
                    limit: Float(limit))
    }
}

/// The eased change between two skies' inputs over drawn-frame time (see the file header).
struct SkyBlend: Equatable, Sendable {
    /// The length of a change: 1.5 s of drawn-frame time.
    static let duration = 1.5

    /// The blend shown when the change began.
    private(set) var from: SkyInputs
    /// The target.
    private(set) var to: SkyInputs
    /// The frame time since the change began, 0…``duration``.
    private(set) var elapsed: Double

    /// A finished blend showing `inputs`.
    init(_ inputs: SkyInputs) {
        from = inputs
        to = inputs
        elapsed = Self.duration
    }

    /// The share of the change done, 0…1 (linear in frame time).
    var progress: Double { min(max(elapsed / Self.duration, 0), 1) }

    /// The eased share: smoothstep of ``progress``.
    var eased: Double {
        let t = progress
        return t * t * (3 - 2 * t)
    }

    /// Whether a change is running.
    var isBlending: Bool { progress < 1 }

    /// The inputs to draw now.
    var current: SkyInputs { isBlending ? SkyInputs.mix(from, to, Float(eased)) : to }

    /// Starts a change from the current blend to `target`.
    mutating func start(to target: SkyInputs) {
        from = current
        to = target
        elapsed = 0
    }

    /// Changes the target of the running change, keeping its progress (a control moved during a change); without a
    /// change, the same as ``jump(to:)``.
    mutating func retarget(_ target: SkyInputs) {
        guard isBlending else { return jump(to: target) }
        to = target
    }

    /// Shows `target` at once (Reduce Motion or the first state).
    mutating func jump(to target: SkyInputs) {
        from = target
        to = target
        elapsed = Self.duration
    }

    /// Ends a running change at its target.
    mutating func finish() {
        from = to
        elapsed = Self.duration
    }

    /// Advances by one drawn frame's `delta` seconds; a negative or non-finite delta does nothing.
    mutating func advance(by delta: Double) {
        guard delta.isFinite, delta > 0, isBlending else { return }
        elapsed = min(elapsed + delta, Self.duration)
        if Self.duration - elapsed < 1e-9 { elapsed = Self.duration }
    }
}
