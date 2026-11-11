// BundleShaders.swift — the Showcase's bundled GLSL files through VisualCore's ShaderBundle (feature 007 T-F604; FR-F604;
// migrated to the shared loader in feature 012 T-A01-106). Files live in the `Shaders` folder reference; names keep their
// extension (`common.glsl`, `gradient.frag`); the VisualCore library (`vc/*.glsl`) is also includable.
import Foundation
import VisualCoreRendering
import VisualCoreShaderSource

enum BundleShaders {
    /// The Showcase's shader bundle.
    static func bundle(_ bundle: Bundle = .main) -> ShaderBundle { ShaderBundle(bundle: bundle, subdirectory: "Shaders") }

    /// All bundled shader files as a library (includes resolve between them and to `vc/*.glsl`).
    static func library(bundle: Bundle = .main) -> ShaderLibrary { self.bundle(bundle).library }

    /// name → source for every bundled shader file.
    static func files(bundle: Bundle = .main) -> [String: String] {
        let shaders = self.bundle(bundle)
        return Dictionary(uniqueKeysWithValues: shaders.names.compactMap { name in shaders.source(name).map { (name, $0) } })
    }

    /// The source of one bundled file, or nil when missing.
    static func source(_ name: String, bundle: Bundle = .main) -> String? { self.bundle(bundle).source(name) }
}
