// RenderState.swift — the pure, host-testable part of a draw's pipeline description (feature 204 R02-F04
// T-R02F04-007; FR-R02F04-020, -023, -024; research D2). The rendering package pairs it with a program as
// `Pipeline` and applies both as one unit; this value names no GL symbol so it stays testable on the host.

/// Immutable fixed-function state of one draw: blending, depth test and write, face culling and colour mask.
///
/// Equal values compare and hash equal, so a `RenderState` can key a cache. Applying it (in the rendering package)
/// sets every field, so the result never depends on the state a previous draw left behind.
public struct RenderState: Hashable, Sendable {
    /// How a fragment's colour is combined with the colour already in the target.
    public enum BlendMode: Hashable, Sendable {
        /// Blending disabled: the fragment replaces the destination.
        case none
        /// Straight alpha: source × srcAlpha + destination × (1 − srcAlpha).
        case alpha
        /// Premultiplied alpha: source + destination × (1 − srcAlpha).
        case premultiplied
        /// Additive: source + destination.
        case additive
    }

    /// Which triangle faces are discarded before rasterisation.
    public enum CullMode: Hashable, Sendable {
        /// Culling disabled: both faces are drawn.
        case none
        /// Back faces (clockwise in the default counter-clockwise front-face winding) are discarded.
        case back
        /// Front faces are discarded.
        case front
    }

    /// Which colour channels a draw may write.
    public struct ColorMask: Hashable, Sendable {
        /// Whether the red channel is written.
        public var red: Bool
        /// Whether the green channel is written.
        public var green: Bool
        /// Whether the blue channel is written.
        public var blue: Bool
        /// Whether the alpha channel is written.
        public var alpha: Bool

        /// A mask with each channel's write flag given explicitly.
        public init(red: Bool, green: Bool, blue: Bool, alpha: Bool) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        /// Every channel written.
        public static let all = ColorMask(red: true, green: true, blue: true, alpha: true)
    }

    /// Blend mode of the draw.
    public var blend: BlendMode
    /// Whether fragments are tested against the depth buffer (less-than comparison).
    public var depthTest: Bool
    /// Whether passing fragments write their depth.
    public var depthWrite: Bool
    /// Which faces are culled.
    public var cull: CullMode
    /// Which colour channels are written.
    public var colorMask: ColorMask

    /// A state with every field given; the defaults describe the `opaque` preset.
    public init(blend: BlendMode = .none, depthTest: Bool = false, depthWrite: Bool = false,
                cull: CullMode = .none, colorMask: ColorMask = .all) {
        self.blend = blend
        self.depthTest = depthTest
        self.depthWrite = depthWrite
        self.cull = cull
        self.colorMask = colorMask
    }

    /// Opaque 2D draw: no blending, no depth test or write, no culling, all channels.
    public static let opaque = RenderState()
    /// Straight-alpha transparent 2D draw; otherwise as `opaque`.
    public static let alphaBlended = RenderState(blend: .alpha)
    /// Additive glow or particle draw without depth write; otherwise as `opaque`.
    public static let additive = RenderState(blend: .additive, depthWrite: false)
    /// Opaque 3D draw: no blending, depth test and write on, back faces culled, all channels.
    public static let opaque3D = RenderState(blend: .none, depthTest: true, depthWrite: true, cull: .back)
}
