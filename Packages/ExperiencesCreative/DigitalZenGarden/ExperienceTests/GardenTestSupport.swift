// GardenTestSupport — feature 146 (A20-P02) T-A20-205 (FR-A20-201–207; SC-A20-201–204). Shared helpers of the Digital
// Zen Garden experience tests: an engine and a shell without a render host (prepared and active, so actions and
// pointer events are carried out with no frame drawn), opening the experience in the one app's session host, drawing
// and reading frames, raking a straight stroke through the actions, dragging through pointer events, the largest gap
// of a stroke and the engine digest of a core. Short runs only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import UIKit
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias GardenFrame = (rgba: [UInt8], width: Int, height: Int)

/// Building, opening, drawing, raking and reading Digital Zen Garden.
@MainActor
enum GardenTest {
    /// The experience id `a20.digital-zen-garden`.
    static var id: ExperienceID {
        DigitalZenGardenExperience.id ?? ExperienceID(rawValue: "a20.unknown")!
    }

    /// The view size of the pointer tests, in points: 400 × 300 (the tray is 4:3 inside a 12-point margin).
    static let viewSize = Vec2(400, 300)

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<GardenCore> {
        var engine = ExperienceEngine<GardenCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The shell of the factory, prepared and active but without a render host.
    static func shell(forceFallback: Bool = false) async throws -> ExperienceShell<GardenPresenter> {
        let shell = DigitalZenGardenExperience.make(id: id, forceFallback: forceFallback)
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<GardenPresenter>) throws -> GardenCore {
        try #require(shell.engine.core)
    }

    /// The engine digest of `shell`'s state.
    static func digest(_ shell: ExperienceShell<GardenPresenter>) throws -> String {
        try shell.engine.digest().hex
    }

    /// Opens Digital Zen Garden in `session` through the factory (with `forceFallback`), lays the view out at `size`
    /// points and draws one frame. A session without a quality pin is pinned to level 0.
    static func open(_ session: ExperienceSession, forceFallback: Bool = false,
                     size: CGSize = CGSize(width: 160, height: 120)) async throws -> ExperienceShell<GardenPresenter> {
        let id = self.id
        var made: ExperienceShell<GardenPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = DigitalZenGardenExperience.make(id: id, forceFallback: forceFallback)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        let shell = try #require(made)
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        return shell
    }

    /// Draws one frame of `session`.
    static func draw(_ session: ExperienceSession) throws {
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> GardenFrame {
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// Sends `control` with `values` through `shell` and records an issue unless it is accepted (feature 147: keeps
    /// the mutating call outside `#expect`).
    @discardableResult
    static func accept(_ shell: ExperienceShell<GardenPresenter>, _ control: String, _ values: [Double] = [],
                       sourceLocation: SourceLocation = #_sourceLocation) -> ActionResult {
        let result = shell.handle(control: control, values: values)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        return result
    }

    /// The values of one `stroke.add` with twelve points evenly from `start` (exclusive) to `end` (inclusive).
    static func addValues(from start: Vec2, to end: Vec2) -> [Double] {
        var values: [Double] = []
        for index in 1...GardenCore.pointsPerAdd {
            let t = Double(index) / Double(GardenCore.pointsPerAdd)
            values.append(start.x + (end.x - start.x) * t)
            values.append(start.y + (end.y - start.y) * t)
        }
        return values
    }

    /// Rakes a straight stroke from `start` to `end` with `rake` through `shell`'s actions; returns the three results.
    @discardableResult
    static func rake(_ shell: ExperienceShell<GardenPresenter>, from start: Vec2, to end: Vec2,
                     rake: Int = 0) -> [ActionResult] {
        [shell.handle(control: "stroke.begin", values: [start.x, start.y, Double(rake)]),
         shell.handle(control: "stroke.add", values: addValues(from: start, to: end)),
         shell.handle(control: "stroke.end")]
    }

    /// The view point (in a view of ``viewSize``) of the tray point `tray`.
    static func viewPoint(_ tray: Vec2, viewSize: Vec2 = viewSize) -> Vec2 {
        let rect = TrayFit.rect(width: viewSize.x, height: viewSize.y)
        return Vec2(rect.x + tray.x * rect.width, rect.y + tray.y * rect.height)
    }

    /// Sends one pointer event of pointer `id` at the view point `location` to `shell`.
    static func touch(_ shell: ExperienceShell<GardenPresenter>, _ phase: PointerPhase, at location: Vec2,
                      id: Int = 1, viewSize: Vec2 = viewSize) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: location, timestamp: 0), viewSize: viewSize)
    }

    /// A drag of pointer `id` through the tray points `points`: began at the first, moved through the others, ended
    /// at the last.
    static func drag(_ shell: ExperienceShell<GardenPresenter>, tray points: [Vec2], id: Int = 1) {
        guard let first = points.first else { return }
        touch(shell, .began, at: viewPoint(first), id: id)
        for point in points.dropFirst() { touch(shell, .moved, at: viewPoint(point), id: id) }
        touch(shell, .ended, at: viewPoint(points[points.count - 1]), id: id)
    }

    /// The largest distance in tray widths between neighbouring points of `points`.
    static func largestGap(_ points: [Vec2]) -> Double {
        var largest = 0.0
        var index = 1
        while index < points.count {
            largest = max(largest, StrokeResampler.trayDistance(points[index - 1], points[index]))
            index += 1
        }
        return largest
    }

    /// The number of pixels whose RGB differs in some channel.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return max(a.count, b.count) / 4 }
        var count = 0
        var i = 0
        while i + 3 < a.count {
            if a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] { count += 1 }
            i += 4
        }
        return count
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func gardenDigest(_ core: GardenCore) throws -> String {
    var builder = DigestBuilder(domain: GardenCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `control` with `values` applied directly, with the result.
func gardenApplied(_ core: GardenCore, _ control: String, _ values: [Double] = []) -> (GardenCore, ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}

/// A garden of `count` one-point fine strokes (dabs) at the tray's centre.
func dabGarden(_ count: Int) -> GardenDocument {
    var document = GardenDocument.empty
    for _ in 0..<count { document.strokes.append(RakeStroke(rake: "fine-rake", points: [Vec2(0.5, 0.5)])) }
    return document
}
