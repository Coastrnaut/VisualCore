// ParticleStage.swift — the sandbox's GPU stage: one VisualCore RenderHost drawing a ParticleLayerScene (feature 034
// A04-P02 T-A04-213; FR-A04-206; plan "Lifecycle contracts"). The app makes no GL or EGL call: VisualCore's host owns
// the context and its thread, and the layer scene owns the GPU objects. The particle state stays in SceneModel (CPU),
// so a context recreation only rebuilds GPU objects.
import ParticleUniverseCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class ParticleStage {
    /// The world the stage shows: the sandbox square −500…500, y up.
    static let world = ParticleLayerScene.WorldRect.square(halfExtent: PlacedForce.worldHalfExtent)

    let host: RenderHost
    let scene: ParticleLayerScene

    /// Creates the host; throws when VisualCore cannot start a context or the scene's setup fails. `source` returns
    /// the particles for each frame (and may advance the simulation); `onFailure` reports errors the host cannot
    /// recover from by itself (unsupported device, scene errors). Context losses and allocation retries are
    /// recovered inside VisualCore and are not reported.
    init(source: @escaping @MainActor (FrameInfo) -> [ParticleInstance], onFailure: @escaping @MainActor (String) -> Void) throws {
        scene = ParticleLayerScene(world: Self.world, background: Vec4(0, 0, 0, 1), source: source)
        host = try RenderHost(scene: scene)
        host.addErrorObserver { error in
            switch error {
            case .contextLost, .allocation: break
            case .unsupported(let m): onFailure("graphics unsupported: \(m)")
            case .scene(let m): onFailure("drawing failed: \(m)")
            }
        }
    }

    func pause() { host.pause() }
    func resume() { host.resume() }
    func destroy() { host.destroy() }
}
