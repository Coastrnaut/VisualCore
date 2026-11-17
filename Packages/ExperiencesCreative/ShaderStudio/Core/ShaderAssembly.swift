// ShaderAssembly — feature 159 (A22-P01) T-A22-106 (FR-A22-104; clarification Q1; contracts/core.md). The person's
// fragment source is placed into the template as three named files of one `ShaderLibrary`, so that every compile
// diagnostic maps back through the expansion's origins to the file and line it came from:
//
//   ss/prelude.glsl  the template's own lines (precision, `v_uv`, `u_time`, `u_resolution`, `fragColor`, and the
//                    `vc/noise.glsl` and `vc/color.glsl` includes);
//   ss/shader.frag   the person's source, unchanged;
//   ss/main.frag     the entry: `#include "ss/prelude.glsl"`, then `#include "ss/shader.frag"`.
//
// The core only builds the texts (data: no expansion, no compile, no GL call). The caller adds these files and
// `ShaderBundle.visualCoreLibrary` to a `ShaderLibrary` and compiles `ss/main.frag` with
// `FullScreenShaderScene.vertexSource`; the library inserts `#version 300 es` itself.
import Foundation

/// The three named GLSL texts that place a person's fragment source into the Shader Studio template
/// (feature 159, clarification Q1).
public struct ShaderAssembly: Sendable, Equatable {
    /// The template's prelude file name.
    public static let preludeFile = "ss/prelude.glsl"
    /// The person's source file name; diagnostics in this file keep their authored line.
    public static let personFile = "ss/shader.frag"
    /// The entry file name, compiled as the fragment shader.
    public static let entryFile = "ss/main.frag"

    /// The prelude text: the precision, the full-screen varying `v_uv`, the reserved uniforms `u_time` and
    /// `u_resolution`, the output `fragColor` and the `vc/noise.glsl` and `vc/color.glsl` includes, one per line,
    /// ending with a newline.
    public static let preludeText = """
    precision highp float;
    in vec2 v_uv;
    uniform float u_time;
    uniform vec2 u_resolution;
    out vec4 fragColor;
    #include "vc/noise.glsl"
    #include "vc/color.glsl"

    """

    /// The entry text: the prelude include, then the person's source include, ending with a newline.
    public static let entryFileText = """
    #include "\(preludeFile)"
    #include "\(personFile)"

    """

    /// The three files by name: ``preludeFile``, ``personFile`` (the source unchanged) and ``entryFile``.
    public let files: [String: String]

    /// The entry text (``entryFileText``), the fragment source to compile under the name ``entryFile``.
    public var entryText: String { files[Self.entryFile] ?? Self.entryFileText }

    /// The person's source as placed in ``personFile``.
    public var personSource: String { files[Self.personFile] ?? "" }

    /// The assembly of `source`, kept byte for byte.
    public init(source: String) {
        files = [Self.preludeFile: Self.preludeText, Self.personFile: source, Self.entryFile: Self.entryFileText]
    }

    /// The assembly of `project`'s source.
    public init(project: ShaderProject) {
        self.init(source: project.source)
    }
}
