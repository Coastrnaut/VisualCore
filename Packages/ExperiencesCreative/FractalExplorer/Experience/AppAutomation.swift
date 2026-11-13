// AppAutomation.swift — the device-campaign automation entry (feature 030 T-A03-505/T-A03-506; FR-A03-502, FR-A03-503,
// FR-A03-505; spec 030 clarifications). Compiled only under DEBUG || VISUALCORE_AUTOMATION; the only trigger is the
// launch environment (VISUALCORE_AUTORUN=<mode>, VISUALCORE_AUTORUN_FRAMES) set by simctl/devicectl. VisualCore's
// AutomationView owns the one RenderHost for the explorer's scene; the explorer model runs unhosted. Modes: the
// built-in smoke, launch and lifecycle, plus the app modes `precision` and `tour`. Reports carry the device model and
// OS only (no identifiers).
#if DEBUG || VISUALCORE_AUTOMATION
import FractalExplorerCore
import Foundation
import QuartzCore
import SwiftUI
import VisualCoreAutomation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
enum AppAutomation {
    /// The requested mode, if this launch is an automation run.
    static let mode = AutomationRunner.requestedMode()
    /// The model of the current run (kept alive for the run's lifetime).
    private(set) static var model: ExplorerModel?

    /// An unhosted explorer with animation off (deterministic pictures) and a throwaway bookmark folder.
    static func makeModel(canvas: Vec2 = Vec2(390, 844)) -> ExplorerModel {
        let m = ExplorerModel(size: canvas, system: SystemAccessibility(reduceMotion: true),
                              bookmarksDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("automation-bookmarks"),
                              hosted: false)
        m.animate = false
        return m
    }

    /// The domain check for every mode: the shader compiled and rendered.
    static func check(_ m: ExplorerModel) -> String? { m.scene.errorMessage.map { "shader error: \($0)" } }

    /// The canvas of a host in points (falls back to 390 × 844 before layout).
    static func canvas(of host: RenderHost) -> Vec2 {
        let b = host.view.bounds.size
        return b.width > 1 && b.height > 1 ? Vec2(Double(b.width), Double(b.height)) : Vec2(390, 844)
    }

    /// The host view's display scale (3 before it is known).
    static func scale(of host: RenderHost) -> Double {
        let s = Double(host.view.traitCollection.displayScale)
        return s > 0 ? s : 3
    }

    /// Share of the image's pixels that are explained by the CPU reference for `state` (the image covers the view):
    /// a pixel is explained when its escape class matches, or when the CPU class changes within one pixel (a boundary
    /// pixel, where 32-bit and 64-bit arithmetic may legitimately differ — feature 027's rule; spec 030 finding
    /// T-A03-505). Precision breakdown shows as blocks wider than a pixel, which this still counts.
    static func agreement(_ image: StillImage, state: FractalState) -> Double {
        let w = image.width, h = image.height, size = state.viewport.size
        var cpu = [Bool](repeating: false, count: (w + 2) * (h + 2))
        for y in -1...h { for x in -1...w {
            let screen = Vec2((Double(x) + 0.5) / Double(w) * size.x, (Double(y) + 0.5) / Double(h) * size.y)
            cpu[(y + 1) * (w + 2) + (x + 1)] = state.escape(at: state.viewport.plane(fromScreen: screen)).interior
        } }
        func c(_ x: Int, _ y: Int) -> Bool { cpu[(y + 1) * (w + 2) + (x + 1)] }
        var explained = 0
        for y in 0..<h { for x in 0..<w {
            let p = image.pixel(x: x, y: y)
            let gpu = Int(p.x) <= 1 && Int(p.y) <= 1 && Int(p.z) <= 1
            if gpu == c(x, y) { explained += 1; continue }
            var boundary = false
            for dy in -1...1 { for dx in -1...1 where c(x + dx, y + dy) != c(x, y) { boundary = true } }
            if boundary { explained += 1 }
        } }
        return Double(explained) / Double(max(1, w * h))
    }

    // MARK: precision (US1)

    /// The precision mode: the reported shader precision, then the zoom ladder at the screen's pixel step.
    static func precision(_ m: ExplorerModel, host: RenderHost, report: inout AutomationReport) {
        let caps = host.capabilities
        let bits = caps.fragmentMantissaBits()
        let ppp = scale(of: host), canvas = canvas(of: host)
        m.mantissaBitsOverride = bits
        m.pixelsPerPointOverride = ppp
        var measurements: [String: Double] = [
            "highpBits": Double(caps.fragmentHighp?.precisionBits ?? -1),
            "highpRangeMax": Double(caps.fragmentHighp?.rangeMax ?? -1),
            "mediumpBits": Double(caps.fragmentMediump?.precisionBits ?? -1),
            "mantissaBitsUsed": Double(bits), "maxRenderSize": Double(host.maxRenderSize), "pixelsPerPoint": ppp,
        ]
        var steps: [PrecisionLadder.Step] = []
        var state = FractalState(size: canvas)
        state.iterationCap = 500
        for (i, zoom) in PrecisionLadder.zooms(canvas: canvas).enumerated() {
            let level = PrecisionMode.level(viewport: PrecisionLadder.canvasViewport(zoom: zoom, canvas: canvas),
                                            mantissaBits: bits, pixelsPerPoint: ppp)
            let clamped = PrecisionLadder.isClamped(zoom: zoom, canvas: canvas, mantissaBits: bits, pixelsPerPoint: ppp)
            state.viewport = PrecisionLadder.patchViewport(zoom: zoom, canvas: canvas, pixelsPerPoint: ppp)
            m.state = state   // drawn unclamped on purpose: the ladder locates the device's own breakdown
            guard host.renderOneFrame(present: false),
                  let image = try? host.renderOffscreen(width: PrecisionLadder.patchPixels, height: PrecisionLadder.patchPixels, time: 0) else {
                report.result = "fail"; report.message = "step \(i) could not be rendered"; return
            }
            steps.append(PrecisionLadder.Step(index: i, zoom: zoom, level: level, clamped: clamped,
                                              agreement: agreement(image, state: state)))
        }
        let verdict = PrecisionLadder.verdict(steps)
        measurements["steps"] = Double(steps.count)
        measurements["clampStep"] = Double(verdict.clampStep ?? -1)
        measurements["breakdownStep"] = Double(verdict.breakdownStep ?? -1)
        measurements["clampZoom"] = verdict.clampStep.map { steps[$0].zoom } ?? -1
        measurements["breakdownZoom"] = verdict.breakdownStep.map { steps[$0].zoom } ?? -1
        measurements["minReliableAgreement"] = verdict.minReliableAgreement ?? -1
        report.frames = steps.count
        report.measurements = measurements
        report.details = [
            "fallback": ExplorerModel.precisionSource(highp: caps.fragmentHighp, mediump: caps.fragmentMediump),
            "ladder": steps.map { "\($0.index) \($0.zoom) \($0.level.rawValue)\($0.clamped ? " clamped" : "") \($0.agreement)" }
                .joined(separator: "; "),
        ]
        if !verdict.pass { report.result = "fail"; report.message = verdict.reason }
    }

    // MARK: tour (US2)

    /// Share of 64 sample points (8 × 8) of a capture of `state` explained by the CPU reference (class match, or a CPU
    /// class change within one capture pixel).
    static func sampleAgreement(_ image: StillImage, state: FractalState) -> Double {
        let size = state.viewport.size
        func cpu(_ x: Int, _ y: Int) -> Bool {
            let screen = Vec2((Double(x) + 0.5) / Double(image.width) * size.x, (Double(y) + 0.5) / Double(image.height) * size.y)
            return state.escape(at: state.viewport.plane(fromScreen: screen)).interior
        }
        var explained = 0
        for j in 0..<8 { for i in 0..<8 {
            let x = (i * 2 + 1) * image.width / 16, y = (j * 2 + 1) * image.height / 16
            let p = image.pixel(x: x, y: y)
            let gpu = Int(p.x) <= 1 && Int(p.y) <= 1 && Int(p.z) <= 1
            let c = cpu(x, y)
            if gpu == c { explained += 1; continue }
            var boundary = false
            for dy in -1...1 { for dx in -1...1 where cpu(x + dx, y + dy) != c { boundary = true } }
            if boundary { explained += 1 }
        } }
        return Double(explained) / 64
    }

    static func thermalName(_ t: ProcessInfo.ThermalState) -> String {
        switch t {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    /// The tour mode: every curated tour at 60 tour steps per second with a timed presented frame per step (capped per
    /// tour by `frameCap` when VISUALCORE_AUTORUN_FRAMES is given), a still per stop at min(1024 px, the device limit)
    /// checked at 64 points, thermal state and Low Power Mode at the start and end. No capture file is left.
    static func tour(_ m: ExplorerModel, host: RenderHost, report: inout AutomationReport, frameCap: Int?) {
        let ppp = scale(of: host), canvas = canvas(of: host)
        m.mantissaBitsOverride = host.capabilities.fragmentMantissaBits()
        m.pixelsPerPointOverride = ppp
        m.state = FractalState(size: canvas)
        let info = ProcessInfo.processInfo
        var details = ["thermalStart": thermalName(info.thermalState), "lowPowerStart": "\(info.isLowPowerModeEnabled)"]
        let capture = StillCapture(folder: StillCapture.folder(named: "AutomationCaptures"))
        let aspect = ExportAspect(id: "canvas", title: "Canvas", width: Int(canvas.x.rounded()), height: Int(canvas.y.rounded()))
        let size = aspect.map { ExportGeometry(maxEdge: host.maxRenderSize).size(longEdge: 1024, aspect: $0) }
        var samples: [Double] = []
        var failures = 0
        var agreements: [Double] = []
        for t in FractalTours.all {
            let timeline = t.timeline(from: PlaneFraming(m.state.viewport), reduceMotion: false)
            var steps = Int((timeline.duration * 60).rounded(.up))
            if let frameCap { steps = min(steps, max(1, frameCap)) }
            var captured = Set<Int>()
            var perTour: [String] = []
            func captureStop(_ index: Int) {
                guard let size else { return }
                m.apply(t.stops[index].framing.viewport(size: canvas))
                var a = 0.0
                if case .done = capture.capture(host: host, size: size, prefix: "Tour"), let image = capture.lastImage {
                    a = sampleAgreement(image, state: m.state)
                }
                capture.removeFile()
                agreements.append(a)
                perTour.append("\(a)")
                captured.insert(index)
            }
            for i in 0..<steps {
                let s = timeline.state(at: Double(i) / 60)
                m.apply(s.framing.viewport(size: canvas))
                let start = CACurrentMediaTime()
                if host.renderOneFrame(present: true) { samples.append((CACurrentMediaTime() - start) * 1000) } else { failures += 1 }
                if s.phase != .flying, !captured.contains(s.stopIndex) { captureStop(s.stopIndex) }
            }
            for index in t.stops.indices where !captured.contains(index) { captureStop(index) }
            details["agreement.\(t.id)"] = perTour.joined(separator: ", ")
        }
        details["thermalEnd"] = thermalName(info.thermalState)
        details["lowPowerEnd"] = "\(info.isLowPowerModeEnabled)"
        report.frames = samples.count
        report.frameTimeMs = FrameTimeStats(samples: samples)
        report.measurements = ["tours": Double(FractalTours.all.count), "stops": Double(agreements.count),
                               "minStopAgreement": agreements.min() ?? 0, "captureLongEdge": Double(size?.longEdge ?? 0)]
        report.details = details
        let leftover = capture.folder.fileCount
        if failures > 0 || leftover > 0 || agreements.contains(where: { $0 < 0.99 }) || size == nil {
            report.result = "fail"
            report.message = "frames failed: \(failures), files left: \(leftover), stops below 99%: \(agreements.filter { $0 < 0.99 }.count)"
        }
    }

    /// The app's own modes for VisualCore's AutomationView.
    /// `tourFrameCap` defaults to VISUALCORE_AUTORUN_FRAMES when that is set (none otherwise).
    static func appModes(_ m: ExplorerModel, tourFrameCap: Int? = defaultTourFrameCap())
        -> [String: @MainActor (RenderScene, RenderHost, inout AutomationReport, Int) -> Void] {
        let cap = tourFrameCap
        return ["precision": { _, host, report, _ in precision(m, host: host, report: &report) },
                "tour": { _, host, report, _ in tour(m, host: host, report: &report, frameCap: cap) }]
    }

    /// The frames-per-tour cap from the launch environment, if given.
    static func defaultTourFrameCap() -> Int? {
        ProcessInfo.processInfo.environment[AutomationRunner.framesKey] != nil ? AutomationRunner.requestedFrames() : nil
    }

    /// The full-screen run: AutomationView hosts the explorer's scene and runs the mode, then the check.
    @ViewBuilder
    static func root(mode: String) -> some View {
        let m = Self.model ?? makeModel()
        let _ = (Self.model = m)
        AutomationView(mode: mode, bundleID: Bundle.main.bundleIdentifier ?? "dev.visualcore.FractalExplorer",
                       makeScene: { m.scene },
                       postRunCheck: { _ in check(m) },
                       appModes: appModes(m))
            .ignoresSafeArea()
            .accessibilityIdentifier("fe.automation")
    }
}
#endif
