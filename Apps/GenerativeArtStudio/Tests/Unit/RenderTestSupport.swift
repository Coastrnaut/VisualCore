// RenderTestSupport — shared helpers for Generative Art Studio pixel tests (feature 012 T-A01-111).
import XCTest
import GenerativeArtStudioCore
import VisualCoreRendering
@testable import GenerativeArtStudio

@MainActor
enum ArtRender {
    static let size = CGSize(width: 64, height: 48)
    static let time = 1.5

    static func document(_ family: SceneFamilyID, seed: UInt64? = nil) throws -> ArtDocument {
        var doc = ArtDocument.from(FamilyCatalog.family(family).defaultPreset, family: family,
                                   id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        if let seed { doc.seed = seed }
        return try doc.validated().document
    }

    /// Renders `document` at the fixed test time and returns pixels plus the live host (caller destroys).
    static func render(_ document: ArtDocument, bundle: ShaderBundle = ArtSceneFactory.shaders, frames: Int = 2) throws
        -> (pixels: [UInt8], scene: ArtScene, host: RenderHost) {
        let scene = ArtSceneFactory.makeScene(for: document, bundle: bundle)
        scene.fixedTime = time
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        for _ in 0..<frames { XCTAssertTrue(host.renderOneFrame(present: false)) }
        return (host.readPixels(), scene, host)
    }

    static func pixels(_ document: ArtDocument) throws -> [UInt8] {
        let r = try render(document)
        defer { r.host.destroy() }
        XCTAssertNil(r.scene.errorMessage, document.familyID)
        return r.pixels
    }
}
