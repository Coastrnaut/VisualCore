// ShaderBundle.swift — loads GLSL files from an app bundle into a ShaderLibrary together with the VisualCore GLSL
// include library `vc/*.glsl` (feature 012 T-A01-104; FR-A01-108; contract specs/012-gas-p01-gallery-domain/contracts/api.md).
import Foundation
import VisualCoreShaderSource

/// Shader sources from a bundle folder (`.vert`, `.frag`, `.glsl`), resolvable as includes of each other and of the
/// VisualCore library (`#include "vc/noise.glsl"`, `vc/hash.glsl`, `vc/palette.glsl`, `vc/sdf.glsl`, `vc/color.glsl`).
public final class ShaderBundle: Sendable {
    /// File extensions loaded from a bundle folder.
    public static let extensions: Set<String> = ["vert", "frag", "glsl"]
    /// The VisualCore GLSL include library: include name → source.
    public static let visualCoreLibrary: [String: String] = {
        guard let dir = Bundle.module.resourceURL?.appendingPathComponent("GLSL/vc") else { return [:] }
        return load(dir, prefix: "vc/")
    }()

    /// Library holding the app files and the VisualCore includes.
    public let library: ShaderLibrary
    private let files: [String: String]

    /// Loads every shader file in `bundle`'s `subdirectory` (the bundle root when nil).
    public convenience init(bundle: Bundle, subdirectory: String? = "Shaders") {
        let root = bundle.resourceURL.map { subdirectory.map($0.appendingPathComponent) ?? $0 }
        self.init(files: root.map { Self.load($0, prefix: "") } ?? [:])
    }

    /// Uses in-memory sources (name → text), for tests and generated shaders.
    public init(files: [String: String]) {
        self.files = files
        var lib = ShaderLibrary()
        for (name, text) in Self.visualCoreLibrary { lib.add(name, text) }
        for (name, text) in files { lib.add(name, text) }
        library = lib
    }

    /// The source of one app file (not a VisualCore include), or nil.
    public func source(_ name: String) -> String? { files[name] }

    /// App file names, sorted.
    public var names: [String] { files.keys.sorted() }

    private static func load(_ dir: URL, prefix: String) -> [String: String] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [:] }
        var out: [String: String] = [:]
        for url in urls where extensions.contains(url.pathExtension) {
            if let text = try? String(contentsOf: url, encoding: .utf8) { out[prefix + url.lastPathComponent] = text }
        }
        return out
    }
}
