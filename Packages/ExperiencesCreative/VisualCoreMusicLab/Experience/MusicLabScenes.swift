// MusicLabScenes — feature 049 (A06-P03) T-A06-307 (FR-A06-310, 311, 314; research D4, D7). The pieces of the three
// scenes that are not plain 2D lines: the ring geometry of the Rings scene and the meshes of the Geometry scene. Every
// GPU object comes from the host's resource registry and is drawn through the host's renderers (no context of its own).
import Foundation
import VisualCoreAudioDSP
import VisualCoreMath
import VisualCoreMusicLabCore
import VisualCoreRendering
import VisualCoreScenes

/// The layout of the Rings scene: five concentric rings of the newest samples.
enum RingLayout {
    /// The number of rings.
    static let ringCount = 5
    /// The segments per ring.
    static let segments = 64

    /// The world points (pixels from the view centre, y up) of ring `ring`: radius `radius` · short side · (0.6 + 0.1 ·
    /// ring), displaced outward by sample · `wobble` · short side; samples are read at evenly spaced indices, each ring
    /// offset so the rings do not repeat one another. Fewer than one sample draws plain circles.
    static func points(ring: Int, samples: [Float], radius: Double, wobble: Double, short: Double) -> [Vec2] {
        let base = radius * short * (0.6 + 0.1 * Double(ring))
        return (0..<segments).map { j in
            let angle = 2 * Double.pi * Double(j) / Double(segments)
            var s = 0.0
            if !samples.isEmpty {
                let index = (j * samples.count / segments + ring * 37) % samples.count
                let v = Double(samples[index])
                s = v.isFinite ? min(max(v, -1), 1) : 0
            }
            let r = base + s * wobble * short
            return Vec2(cos(angle) * r, sin(angle) * r)
        }
    }
}

/// The meshes of the Geometry scene: a lit sphere and one cube drawn sixteen times on a ring, with depth.
@MainActor
final class GeometryMeshes {
    /// The ring radius of the cubes in world units.
    static let ringRadius = 2.2
    /// The fixed camera: 30° above the ring.
    static let camera = OrbitCamera(target: .zero, distance: 7, yaw: 0, pitch: Double.pi / 6)
    /// The sphere colour.
    static let sphereColor = Vec4(1.0, 0.45, 0.6, 1)
    /// The cube colour.
    static let cubeColor = Vec4(0.45, 0.6, 1.0, 1)

    private let sphere: MeshRenderer
    private let cube: MeshRenderer
    private let pass: DepthMeshPass

    /// Builds the sphere and cube renderers and the depth pass in `registry`.
    init(registry: ResourceRegistry) throws {
        sphere = try MeshRenderer(mesh: .uvSphere(segments: 24, rings: 12), registry: registry)
        cube = try MeshRenderer(mesh: .cube(), registry: registry)
        pass = DepthMeshPass(registry: registry)
        pass.clearColor = Vec4(Double(MusicLabPresenter.background.red), Double(MusicLabPresenter.background.green),
                               Double(MusicLabPresenter.background.blue), 1)
    }

    /// The draw items: the sphere scaled by `pulse` and turned by `angle`, and cube i on the ring at `angle` + 2πi/16
    /// with height 0.15 + `lift` · bars[i] (bars are 0…1 display heights).
    func items(pulse: Double, lift: Double, angle: Double, bars: [Double]) -> [DepthMeshPass.Item] {
        let turn = Mat4.rotation(Quat(axis: Vec3(0, 1, 0), angle: angle))
        var items = [DepthMeshPass.Item(renderer: sphere, model: turn * Mat4.scale(Vec3(pulse, pulse, pulse)),
                                        color: Self.sphereColor)]
        for i in 0..<16 {
            let a = angle + 2 * Double.pi * Double(i) / 16
            let height = 0.15 + lift * (i < bars.count ? bars[i] : 0)
            let position = Vec3(cos(a) * Self.ringRadius, height / 2 - 0.8, sin(a) * Self.ringRadius)
            let model = Mat4.translation(position) * Mat4.rotation(Quat(axis: Vec3(0, 1, 0), angle: -a))
                * Mat4.scale(Vec3(0.3, height, 0.3))
            items.append(DepthMeshPass.Item(renderer: cube, model: model, color: Self.cubeColor))
        }
        return items
    }

    /// Draws `items` into the host's framebuffer through the depth pass.
    func draw(_ items: [DepthMeshPass.Item], context: RenderContext) throws {
        try pass.draw(items, camera: Self.camera, context: context)
    }

    /// Releases the renderers and the depth target.
    func release() {
        sphere.release()
        cube.release()
        pass.release()
    }
}
