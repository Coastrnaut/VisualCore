// ArtSceneFactory.swift — turns a validated ArtDocument into a VisualCore RenderScene (feature 012 T-A01-109;
// FR-A01-102, FR-A01-106). All GPU work happens through VisualCore (RenderHost, ResourceRegistry); the app creates no EGL.
import GenerativeArtStudioCore
import VisualCoreParameters
import VisualCoreRendering

/// A scene for one composition: reports shader errors and can be pinned to an explicit time.
@MainActor
protocol ArtScene: RenderScene {
    /// The first shader diagnostic (`file:line: message`), or nil.
    var errorMessage: String? { get }
    /// When set, every frame renders this time (deterministic previews and tests).
    var fixedTime: Double? { get set }
    /// Multiplier on frame time when not fixed (0.5 under Reduce Motion).
    var timeScale: Double { get set }
    /// Points → pixels factor of the hosting view.
    var displayScale: Double { get set }
}

extension FullScreenShaderScene: ArtScene {
    var displayScale: Double { get { 1 } set {} }
}

@MainActor
enum ArtSceneFactory {
    /// The app's shaders (folder `Shaders` in the app bundle) plus the VisualCore GLSL library.
    static let shaders = ShaderBundle(bundle: .module, subdirectory: "Shaders")

    /// A scene for `document` (validated); `bundle` is injectable for tests.
    static func makeScene(for document: ArtDocument, bundle: ShaderBundle = shaders) -> ArtScene {
        let family = document.family ?? FamilyCatalog.family(.gradientNoise)
        switch family.kind {
        case .shader(let fragment):
            let scene = FullScreenShaderScene(fragmentName: fragment, bundle: bundle)
            configure(scene, document: document)
            return scene
        case .particles(let background):
            let scene = ParticlesArtScene(document: document, background: FullScreenShaderScene(fragmentName: background, bundle: bundle))
            configure(scene.background, document: document)
            return scene
        }
    }

    /// Applies an edited composition to a live scene (uniform values, palette, seed offsets; particles replay restart).
    /// Values are read at render time, so rapid edits apply only the latest one at the next frame.
    static func apply(_ document: ArtDocument, to scene: ArtScene) {
        if let shader = scene as? FullScreenShaderScene {
            configure(shader, document: document)
        } else if let particles = scene as? ParticlesArtScene {
            particles.update(document: document)
            configure(particles.background, document: document)
        }
    }

    /// Binds a document's values, palette (linear light) and seed offsets.
    static func configure(_ scene: FullScreenShaderScene, document: ArtDocument) {
        scene.parameters = document.parameters
        let palette = FamilyCatalog.palette(document.paletteID) ?? Palette.builtIns[0]
        scene.palette = palette.linearStops.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
        let o = SeedOffsets.of(document.seed)
        scene.seedOffsets = SIMD4(Float(o.x), Float(o.y), Float(o.z), Float(o.w))
    }
}
