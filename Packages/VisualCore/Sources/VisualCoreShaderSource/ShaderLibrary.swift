// ShaderLibrary.swift — named GLSL ES 3.00 sources with #include expansion and a line map
// (feature 004 T-F305; FR-F301–FR-F303, FR-F317). Contract:
// specs/002-architecture-contracts/contracts/resources-shaders-errors.md §Shaders.
// Feature 206 T-R02F06-003 (FR-R02F06-001, FR-R02F06-004): each file is included at most once per expansion,
// the mid-expansion size guard counts UTF-8 bytes, and an overload takes a validated `DefineSet`, a
// `PrecisionPolicy` and the `ShaderStageKind`.
//
import Foundation

// Expanded layout: line 1 `#version 300 es` (from the main source, or generated), then one generated
// `#define` line per define (sorted by name), then (fragment stage with a precision policy and no float precision
// statement only) one generated `precision … float;` line, then the content with every `#include "name"` replaced
// recursively; a file already included in this expansion is skipped. Every expanded line maps back to (file, line);
// generated lines map to `<generated>`.

/// The shader stage an expansion is for; only fragment shaders get a default precision (feature 206).
public enum ShaderStageKind: String, Sendable, CaseIterable {
    /// A vertex shader (GLSL ES 3.00 gives it `highp float` by default).
    case vertex
    /// A fragment shader (no default float precision).
    case fragment
}

/// Where an expanded line came from.
public struct SourceOrigin: Sendable, Equatable, Hashable, Codable {
    /// Source name the line came from, or `<generated>` for synthesized lines.
    public let file: String
    /// 1-based line in `file`; 0 for generated lines.
    public let line: Int
    /// Creates an origin for 1-based `line` of `file`.
    public init(file: String, line: Int) { self.file = file; self.line = line }
    /// Origin of synthesized lines (`#version`, `#define`): file `<generated>`, line 0.
    public static let generated = SourceOrigin(file: "<generated>", line: 0)
}

/// Rejections before any GPU work (FR-F302, FR-F317).
public enum ShaderSourceError: Error, Equatable, Sendable {
    case tooLarge(Int)
    case tooDeep(Int)
    case cycle([String])
    case unknownInclude(String, file: String, line: Int)
    case unsupportedVersion(file: String, line: Int)
    case unknownSource(String)
}

/// The result of expansion: GLSL text plus a line map.
public struct ExpandedShader: Sendable, Equatable {
    /// Expanded GLSL ES 3.00 text, lines joined with `\n`, at most 64 KiB of UTF-8.
    public let text: String
    /// `origins[i]` is the origin of expanded line `i + 1`.
    public let origins: [SourceOrigin]
    /// Defines in the order they were emitted (sorted by name).
    public let defines: [String]
    /// `highp` requests a `.medium` policy cannot honour, in expanded-line order; empty otherwise (feature 206).
    public internal(set) var precisionFindings: [PrecisionFinding] = []

    /// Origin of a 1-based expanded line; `<generated>` when out of range.
    public func origin(ofExpandedLine line: Int) -> SourceOrigin {
        guard line >= 1, line <= origins.count else { return .generated }
        return origins[line - 1]
    }
}

/// Named GLSL ES 3.00 sources expanded with `#include "name"` (depth ≤ 8, ≤ 64 KiB) and injected `#define`s.
public struct ShaderLibrary: Sendable {
    /// Maximum UTF-8 size of an expanded shader (64 KiB); larger results throw `tooLarge`.
    public static let maxExpandedBytes = 64 * 1024
    /// Maximum `#include` nesting depth (8); deeper nesting throws `tooDeep`.
    public static let maxIncludeDepth = 8
    /// The only accepted version directive, emitted as expanded line 1.
    public static let versionLine = "#version 300 es"

    private var sources: [String: String] = [:]

    /// Creates an empty library.
    public init() {}

    /// Registers `text` under `name`, replacing any source already registered with that name.
    public mutating func add(_ name: String, _ text: String) { sources[name] = text }

    /// Whether a source is registered under `name`.
    public func contains(_ name: String) -> Bool { sources[name] != nil }

    /// Expands a named source.
    public func expand(_ name: String, defines: [String: String] = [:]) throws(ShaderSourceError) -> ExpandedShader {
        guard let text = sources[name] else { throw .unknownSource(name) }
        return try expand(source: text, named: name, defines: defines)
    }

    /// Expands an inline source whose includes resolve against this library.
    public func expand(source text: String, named name: String, defines: [String: String] = [:]) throws(ShaderSourceError) -> ExpandedShader {
        try expand(source: text, named: name, defineLines: defineLines(defines), precision: nil, stage: .vertex)
    }

    /// Expands a named source with validated defines; a fragment shader without a float precision statement gets
    /// `policy.statement` as a generated line after the defines (`precision` nil inserts nothing). With `.medium`,
    /// every fragment-source `highp` is reported in `precisionFindings` (feature 206, FR-R02F06-004).
    public func expand(_ name: String, defines: DefineSet, precision: PrecisionPolicy?, stage: ShaderStageKind) throws(ShaderSourceError) -> ExpandedShader {
        guard let text = sources[name] else { throw .unknownSource(name) }
        return try expand(source: text, named: name, defines: defines, precision: precision, stage: stage)
    }

    /// Expands an inline source with validated defines, a precision policy and a stage (see `expand(_:defines:precision:stage:)`).
    public func expand(source text: String, named name: String, defines: DefineSet, precision: PrecisionPolicy?,
                       stage: ShaderStageKind) throws(ShaderSourceError) -> ExpandedShader {
        try expand(source: text, named: name, defineLines: defines.lines, precision: precision, stage: stage)
    }

    private func expand(source text: String, named name: String, defineLines emittedDefines: [String],
                        precision: PrecisionPolicy?, stage: ShaderStageKind) throws(ShaderSourceError) -> ExpandedShader {
        var output = Output()
        var body = splitLines(text)
        var firstBodyLine = 1
        // Version: an explicit first non-empty line must be exactly GLSL ES 3.00.
        if let first = body.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           body[first].trimmingCharacters(in: .whitespaces).hasPrefix("#version") {
            guard isES300(body[first]) else { throw .unsupportedVersion(file: name, line: first + 1) }
            // Keep numbering; the version line is emitted first below.
            if first == 0 { body.removeFirst(); firstBodyLine = 2 } else { body[first] = "" }
            try output.add(Self.versionLine, SourceOrigin(file: name, line: first + 1))
        } else {
            try output.add(Self.versionLine, .generated)
        }
        for line in emittedDefines { try output.add(line, .generated) }
        let headerCount = output.lines.count
        var included: Set<String> = [name]
        try append(lines: body, from: name, startingAt: firstBodyLine, stack: [name], included: &included, into: &output)
        var findings: [PrecisionFinding] = []
        if stage == .fragment, let precision {
            if !output.lines.contains(where: PrecisionScan.isFloatPrecisionStatement) {
                output.lines.insert(precision.statement, at: headerCount)
                output.origins.insert(.generated, at: headerCount)
            }
            if precision == .medium {
                for (line, origin) in zip(output.lines, output.origins) where origin != .generated {
                    if let finding = PrecisionScan.finding(line, origin: origin) { findings.append(finding) }
                }
            }
        }
        let result = output.lines.joined(separator: "\n")
        let bytes = result.utf8.count
        guard bytes <= Self.maxExpandedBytes else { throw .tooLarge(bytes) }
        var expanded = ExpandedShader(text: result, origins: output.origins, defines: emittedDefines)
        expanded.precisionFindings = findings
        return expanded
    }

    /// Expanded lines with a running UTF-8 byte count of their `\n`-joined text (FR-R02F06-001, research R2).
    private struct Output {
        var lines: [String] = []
        var origins: [SourceOrigin] = []
        var bytes = 0

        mutating func add(_ line: String, _ origin: SourceOrigin) throws(ShaderSourceError) {
            bytes += (lines.isEmpty ? 0 : 1) + line.utf8.count
            // Size guard during expansion so pathological includes stop early.
            guard bytes <= ShaderLibrary.maxExpandedBytes else { throw .tooLarge(bytes) }
            lines.append(line)
            origins.append(origin)
        }
    }

    private func append(lines body: [String], from file: String, startingAt firstLine: Int, stack: [String],
                        included: inout Set<String>, into output: inout Output) throws(ShaderSourceError) {
        for (offset, line) in body.enumerated() {
            let lineNumber = firstLine + offset
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#version") { throw .unsupportedVersion(file: file, line: lineNumber) }
            if let include = includeName(trimmed) {
                if stack.contains(include) { throw .cycle(stack + [include]) }
                guard let text = sources[include] else { throw .unknownInclude(include, file: file, line: lineNumber) }
                // Include once: a file already pasted in this expansion is skipped (FR-R02F06-001, research R1).
                if included.contains(include) { continue }
                let depth = stack.count   // main file has depth 0, its includes depth 1, ...
                guard depth <= Self.maxIncludeDepth else { throw .tooDeep(depth) }
                included.insert(include)
                try append(lines: splitLines(text), from: include, startingAt: 1, stack: stack + [include],
                           included: &included, into: &output)
                continue
            }
            try output.add(line, SourceOrigin(file: file, line: lineNumber))
        }
    }

    private func includeName(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("#include") else { return nil }
        let rest = trimmed.dropFirst("#include".count).trimmingCharacters(in: .whitespaces)
        guard rest.count >= 2, rest.first == "\"", rest.last == "\"" else { return nil }
        return String(rest.dropFirst().dropLast())
    }

    private func isES300(_ line: String) -> Bool {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init) == ["#version", "300", "es"]
    }

    private func defineLines(_ defines: [String: String]) -> [String] {
        defines.keys.sorted().map { "#define \($0) \(defines[$0]!)" }
    }

    private func splitLines(_ text: String) -> [String] {
        var parts = text.components(separatedBy: "\n")
        if parts.last == "" { parts.removeLast() }   // a trailing newline does not add a line
        return parts
    }
}
