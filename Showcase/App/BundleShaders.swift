// BundleShaders.swift — loads the app's bundled GLSL files into a VisualCore ShaderLibrary (feature 007 T-F604; FR-F604).
// Files live in the `Shaders` folder reference; names keep their extension (`common.glsl`, `gradient.frag`).
import Foundation
import VisualCoreShaderSource

enum BundleShaders {
    static let extensions: Set<String> = ["glsl", "vert", "frag"]

    /// All bundled shader files as a library (includes resolve between them).
    static func library(bundle: Bundle = .main) -> ShaderLibrary {
        var lib = ShaderLibrary()
        for (name, text) in files(bundle: bundle) { lib.add(name, text) }
        return lib
    }

    /// name → source for every bundled shader file.
    static func files(bundle: Bundle = .main) -> [String: String] {
        guard let dir = bundle.resourceURL?.appendingPathComponent("Shaders"),
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [:] }
        var out: [String: String] = [:]
        for url in urls where extensions.contains(url.pathExtension) {
            if let text = try? String(contentsOf: url, encoding: .utf8) { out[url.lastPathComponent] = text }
        }
        return out
    }

    /// The source of one bundled file, or nil when missing.
    static func source(_ name: String, bundle: Bundle = .main) -> String? { files(bundle: bundle)[name] }
}
