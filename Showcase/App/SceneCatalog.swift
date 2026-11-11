// SceneCatalog.swift — the Showcase's scenes and their accessible descriptions (feature 007 T-F604; FR-F603, FR-F609;
// data model specs/007-showcase-app/data-model.md).
import VisualCoreRendering
import VisualCoreScenes

/// A scene the Showcase can host: a RenderScene that reports status, errors and accepts touches.
@MainActor
protocol ShowcaseRenderScene: RenderScene {
    /// Scene-specific diagnostics, e.g. `touch=120,340` or `passes=a>b>c` (shown as `showcase.status`).
    var status: String { get }
    /// A readable, user-facing error (shader file and line, missing asset), or nil.
    var errorMessage: String? { get }
    /// Points → pixels factor of the hosting view.
    var scale: Double { get set }
    func handle(_ event: PointerEvent)
    /// Rebuilds after a recoverable error (Retry button).
    func retry()
    /// Post-processing on/off for scenes that have it (shown as `showcase.effectToggle`); nil when not applicable.
    var effectsEnabled: Bool? { get set }
}

extension ShowcaseRenderScene {
    func handle(_ event: PointerEvent) {}
    func retry() {}
    var effectsEnabled: Bool? { get { nil } set {} }
}

struct SceneDescriptor: Identifiable {
    /// Stable kebab-case id (accessibility identifier `showcase.scene.<id>`).
    let id: String
    let title: String
    let summary: String
    /// VoiceOver description of what the scene shows.
    let accessibilityDescription: String
    /// VoiceOver hint describing how to interact.
    let interactionHint: String
    let make: @MainActor (ShowcaseSettings) -> ShowcaseRenderScene
}

enum SceneCatalog {
    /// Scenes in display order (FR-F603: at least five).
    @MainActor static var all: [SceneDescriptor] {
        [
            SceneDescriptor(id: "gradient-texture", title: "Shader Gradient and Texture",
                            summary: "Shaders loaded from bundled files with an include, plus a bundled texture.",
                            accessibilityDescription: "Left half: a slowly shifting rainbow gradient. Right half: a gray checkerboard texture.",
                            interactionHint: "No touch interaction. Use diagnostics to inspect the renderer.") { GradientTextureScene(settings: $0) },
            SceneDescriptor(id: "animated-geometry", title: "Animated Geometry",
                            summary: "Lit 3D meshes spinning on a timeline; drag to orbit the camera.",
                            accessibilityDescription: "A blue cube on the left and an orange sphere on the right, gently spinning and bobbing.",
                            interactionHint: "Drag to orbit the camera around the shapes.") { AnimatedGeometryScene(settings: $0) },
            SceneDescriptor(id: "distortion", title: "Touch Distortion",
                            summary: "A ripple shader bends the image wherever you touch.",
                            accessibilityDescription: "Diagonal colored stripes that ripple outward from your finger.",
                            interactionHint: "Touch or drag anywhere to move the ripple.") { DistortionScene(settings: $0) },
            SceneDescriptor(id: "particles", title: "Particle System",
                            summary: "Thousands of particles with gravity; drag to spawn, pinch to zoom.",
                            accessibilityDescription: "A dark space where glowing particles fountain up and fall toward a horizontal bar.",
                            interactionHint: "Drag to spawn particles. Pinch with two fingers to zoom.") { ParticleShowcaseScene(settings: $0) },
            SceneDescriptor(id: "post-processing", title: "Multi-pass Post-processing",
                            summary: "Color grade, bloom glow and wave distortion over the animated shapes; toggle it off to compare.",
                            accessibilityDescription: "The spinning cube and sphere with a warm color grade, a soft glow and a gentle wave.",
                            interactionHint: "Use the Post-processing switch to compare. Drag to orbit.") { PostProcessingScene(settings: $0) },
        ]
    }

    /// Problems with a catalog: duplicate or malformed ids and empty texts.
    static func problems(_ scenes: [SceneDescriptor]) -> [String] {
        var out: [String] = [], seen = Set<String>()
        for s in scenes {
            if !seen.insert(s.id).inserted { out.append("duplicate id \(s.id)") }
            if s.id.isEmpty || s.id.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) == nil {
                out.append("id '\(s.id)' is not kebab-case")
            }
            for (name, text) in [("title", s.title), ("summary", s.summary), ("accessibilityDescription", s.accessibilityDescription),
                                 ("interactionHint", s.interactionHint)] where text.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append("\(s.id): empty \(name)")
            }
        }
        return out
    }
}
