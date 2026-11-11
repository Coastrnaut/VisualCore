// GradientTextureScene.swift — Showcase scene 1: shaders loaded from bundled files with an include, and a bundled
// texture (feature 007 T-F605; FR-F603, FR-F604; US2 AC1/AC3).
import CoreGraphics
import CVisualCoreGL
import Foundation
import UIKit
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class GradientTextureScene: ShowcaseRenderScene {
    private let settings: ShowcaseSettings
    private var injectError: Bool
    private var program: ShaderProgram?
    private var texture: Texture?
    private var textureSize = (0, 0)
    private var needsReload = true
    private var time = 0.0
    private(set) var errorMessage: String?
    var scale = 1.0
    var status: String {
        errorMessage == nil ? "shader=\(fragmentName) texture=\(textureSize.0)x\(textureSize.1)" : "shader error"
    }
    private var fragmentName: String { injectError ? "broken.frag" : "gradient.frag" }

    init(settings: ShowcaseSettings) {
        self.settings = settings
        injectError = settings.injectShaderError
    }

    func retry() {
        injectError = false
        needsReload = true
    }

    /// Decodes a bundled PNG into tightly packed RGBA8 rows, bottom-up (GL order).
    static func loadRGBA(named name: String) -> (pixels: [UInt8], width: Int, height: Int)? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil),
              let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ok = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            // Flip so row 0 is the bottom row.
            ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (pixels, w, h) : nil
    }

    private func load(_ context: RenderContext) {
        needsReload = false
        if let program { context.resources.release(program) }
        program = nil
        guard let vs = BundleShaders.source("gradient.vert"), let fs = BundleShaders.source(fragmentName) else {
            errorMessage = "Missing bundled shader gradient.vert or \(fragmentName)"
            return
        }
        do {
            program = try context.resources.program(vertex: vs, fragment: fs, library: BundleShaders.library(),
                                                    vertexName: "gradient.vert", fragmentName: fragmentName)
            errorMessage = nil
        } catch ShaderError.compile(let diagnostics), ShaderError.link(let diagnostics) {
            errorMessage = diagnostics.first.map { "\($0.file):\($0.line): \($0.message)" } ?? "Shader failed"
        } catch {
            errorMessage = "Shader failed: \(error)"
        }
        if texture == nil {
            guard let image = Self.loadRGBA(named: "checker.png") else {
                errorMessage = "Missing bundled texture checker.png"
                return
            }
            do {
                let t = try context.resources.makeTexture(width: image.width, height: image.height, label: "checker")
                t.upload(rgba: image.pixels)
                texture = t
                textureSize = (image.width, image.height)
            } catch { errorMessage = "Texture failed: \(error)" }
        }
    }

    func setup(_ context: RenderContext) throws {
        texture = nil
        program = nil
        load(context)
    }

    func resize(_ context: RenderContext) {}

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if needsReload { load(context) }
        if !settings.reduceMotion { time += frame.delta }
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let program, let texture else { return }
        program.use()
        texture.bind(unit: 0)
        program.set("u_texture", Int32(0))
        program.set("u_time", Float(time))
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    func teardown(_ context: RenderContext) {
        if let program { context.resources.release(program) }
        if let texture { context.resources.release(texture) }
        program = nil
        texture = nil
    }
}
