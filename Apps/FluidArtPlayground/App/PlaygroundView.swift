// PlaygroundView.swift — the fluid canvas screen (feature 019 T-A02-112; feature 020 T-A02-213; FR-A02-106,
// FR-A02-208; contracts/app-splats.md). The screen owns exactly one RenderHost (VisualCore's audited EGL host) and
// destroys it when it goes away; the app creates no EGL context. Touches arrive through `RenderHost.pointerHandler`,
// become evenly spaced samples (VisualCore PointerVelocityTracker) and capped splats (SplatQueue), drained once per
// rendered frame. "Add splash" is the control alternative to swiping. Touch paths are never recorded or stored.
import FluidArtPlaygroundCore
import QuartzCore
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreEffects
import VisualCoreEffectsGraph
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreUI

@MainActor
@Observable
final class PlaygroundModel {
    let scene: FluidFieldsScene
    /// Wraps the fluid scene with VisualCore's effect graph: a bloom for Glowing dye, bypassed for Ink and Smoke,
    /// with the flash limiter under Reduce Flashing (feature 022 FR-A02-403).
    let effects: EffectScene
    /// The system's Reduce Flashing ("Dim Flashing Lights") and Reduce Motion state.
    let accessibility = SystemAccessibilityObserver()
    private(set) var host: RenderHost?
    private(set) var failure: String?
    private(set) var splashes = 0
    private(set) var queue: SplatQueue
    /// The live tuning (feature 021): every change reaches the scene on the next frame without a rebuild.
    var configuration: FluidConfiguration {
        didSet {
            scene.update(configuration: configuration)
            queue.update(configuration: scene.configuration)
            applyEffects()
        }
    }
    /// The automatic quality tier (feature 021 T-A02-308; FR-A02-308), decided every stepped frame by VisualCore's
    /// QualityPolicy from the thermal state and Low Power Mode, read locally and never stored.
    private(set) var tier = 0
    /// The current tier's name, shown in the Adjust panel.
    private(set) var tierName = FluidQuality.name(0)
    private var policy = QualityPolicy(tierCount: FluidQuality.tierCount)
    /// Test seam: the device state (default: ProcessInfo's thermal state and Low Power Mode).
    var deviceState: () -> (thermal: FramePacing.Thermal, lowPower: Bool) = {
        let info = ProcessInfo.processInfo
        return (FramePacing.Thermal(rawValue: info.thermalState.rawValue) ?? .nominal, info.isLowPowerModeEnabled)
    }
    /// Test seam: monotonic seconds (default: CACurrentMediaTime).
    var clock: () -> Double = { CACurrentMediaTime() }
    private var tracker = PointerVelocityTracker(spacing: 1)
    /// Pinch to resize the brush (feature 022; spec 022 clarification 2): VisualCore's PointerTracker and
    /// PinchRecognizer, fed in that order.
    private var pointers = PointerTracker()
    private var pinch = PinchRecognizer()
    private var pinchStartRadius = 0.04
    /// True from the second finger landing until every finger has lifted; no splats are made meanwhile.
    private(set) var pinching = false

    /// `forceFallback` stores the fields in RGBA8 even where half-float works (tests of the fallback path).
    init(configuration: FluidConfiguration = FluidConfiguration(), maxEdge: Int = 512, forceFallback: Bool = false) {
        scene = FluidFieldsScene(configuration: configuration, forceFallback: forceFallback, maxEdge: maxEdge)
        queue = SplatQueue(configuration: configuration)
        self.configuration = scene.configuration
        effects = EffectScene(content: scene, graph: Self.glowGraph)
        scene.splatSource = { [weak self] in self?.drain() ?? [] }
        do {
            let host = try RenderHost(scene: effects)
            host.pointerHandler = { [weak self] event in self?.handle(event) }
            self.host = host
        } catch {
            failure = "The graphics view could not start: \(error)"
        }
        // Setup ran inside RenderHost.init and may have capped the grid by the device; forces convert with the grid
        // the fields really use (feature 020 T-A02-216).
        queue = SplatQueue(configuration: scene.configuration)
        self.configuration = scene.configuration
        applyEffects()
    }

    /// The glow: VisualCore's bloom (threshold 0.6, intensity 1.2, radius 8; spec 022 clarification 1).
    static let glowGraph = EffectGraphDescription(passes: [
        EffectPassDescription(id: "glow", type: "bloom", inputs: ["input": "scene"], output: "glow",
                              params: ["threshold": [0.6], "intensity": [1.2], "radius": [8]]),
    ], output: "glow")

    /// Glow only for Glowing dye; Reduce Flashing adds VisualCore's flash limiter.
    func applyEffects() {
        effects.bypassEffects = !scene.palette.glow
        accessibility.refresh()
        effects.reduceFlashing = accessibility.current.dimFlashingLights
    }

    /// Returns every tuning value to its default (the grid stays as set up).
    func resetConfiguration() {
        var c = FluidConfiguration()
        c.gridWidth = configuration.gridWidth
        c.gridHeight = configuration.gridHeight
        configuration = c
    }

    /// Resampling spacing in points: half the brush radius on the current view (spec 020 clarification 3).
    var spacing: Double {
        guard let size = host?.view.bounds.size, size.width > 0, size.height > 0 else { return 1 }
        return scene.configuration.brushRadius * Double(min(size.width, size.height)) / 2
    }

    /// One touch event from the canvas: a pinch resizes the brush; otherwise the event is resampled by the tracker,
    /// converted and queued.
    func handle(_ event: PointerEvent) {
        guard let size = host?.view.bounds.size else { return }
        pointers.handle(event)
        pinch.handle(event, tracker: pointers)
        if !pinching, pointers.count >= 2 {
            // The second finger ends every stroke in progress; pinch mode takes over until all fingers lift.
            pinching = true
            pinchStartRadius = configuration.brushRadius
            for id in pointers.active.keys {
                _ = tracker.handle(PointerEvent(id: id, phase: .cancelled, location: event.location, timestamp: event.timestamp))
                queue.forget(pointer: id)
            }
        }
        if pinching {
            if pinch.state.isActive {
                let range = FluidConfiguration.brushRadiusRange
                let radius = min(max(pinchStartRadius * pinch.scale, range.lowerBound), range.upperBound)
                if radius != configuration.brushRadius { configuration.brushRadius = radius }
            }
            if pointers.count == 0 {
                pinching = false
                pinch.reset()
            }
            return
        }
        paint(event, viewSize: size)
    }

    /// The painting path of one event (no pinch recognition): resampled by the tracker, converted and queued. The
    /// deterministic test mode feeds its multi-pointer script here, since several fingers would otherwise pinch.
    func paint(_ event: PointerEvent, viewSize size: CGSize) {
        if tracker.activeCount == 0, abs(tracker.spacing - spacing) > 1e-9 {
            tracker = PointerVelocityTracker(spacing: spacing)
        }
        if event.phase == .cancelled { queue.forget(pointer: event.id) }
        let samples = tracker.handle(event)
        queue.add(samples, viewSize: SIMD2(Double(size.width), Double(size.height)))
    }

    /// Called at the start of every stepped frame with that frame's index (from 0), before the queue is drained.
    /// The deterministic test mode (feature 023 T-A02-506) feeds its scripted touches here.
    var beforeDrain: ((Int) -> Void)?
    /// Stepped frames drained since creation.
    private(set) var drainedFrames = 0

    /// The control alternative to swiping: one deterministic splash, announced to VoiceOver.
    func addSplash() {
        queue.addSplash()
        splashes += 1
        AccessibilityNotification.Announcement("Splash added").post()
    }

    /// Called once per stepped frame: decide the tier, apply its iterations to the scene and drain the queue under its
    /// splat cap. The queue itself is never cleared by a tier change.
    private func drain() -> [Splat] {
        beforeDrain?(drainedFrames)
        drainedFrames += 1
        let state = deviceState()
        let decided = policy.decide(thermal: state.thermal, lowPower: state.lowPower, now: clock())
        if decided != tier {
            tier = decided
            tierName = FluidQuality.name(decided)
        }
        // Follows Reduce Flashing changes during the session (EffectScene rebuilds only on a change).
        effects.reduceFlashing = accessibility.current.dimFlashingLights
        let parameters = FluidQuality.parameters(tier: tier, configuration: configuration)
        scene.qualityIterations = parameters.iterations
        return queue.drain(max: parameters.splatCap)
    }

    /// The spoken canvas value.
    var description: String {
        // Reads the observed `configuration` so VoiceOver's label follows palette and tuning changes.
        FluidCanvasDescription.text(configuration: configuration, storage: scene.precision ?? .unorm8,
                                    paused: control.paused || scene.paused || host?.state != .active, splashes: splashes)
    }

    // MARK: Pause, Step, Reset (feature 023 T-A02-505; FR-A02-501–FR-A02-503)

    /// Running or paused, with the control labels and hints (FluidArtPlaygroundCore).
    private(set) var control = SimulationControl()
    /// Resets applied (shown nowhere; read by tests).
    private(set) var resets = 0

    /// Pauses or resumes the simulation; the canvas keeps displaying while paused.
    func togglePause() {
        let announcement = control.toggle()
        scene.paused = control.paused
        announce(announcement)
    }

    /// Runs exactly one simulation step on the next frame; only while paused.
    func step() {
        guard control.stepEnabled else { return }
        scene.requestStep()
        announce(.stepped)
    }

    /// Back to the starting picture: strokes in progress end, queued touches are dropped, the fields restart from the
    /// seed on the next frame. The pause state, tuning, palette and brush are kept; the renderer is not rebuilt.
    func resetCanvas() {
        endStrokes()
        _ = queue.drain()
        scene.resetFields()
        resets += 1
        announce(.reset)
    }

    /// Ends every active stroke (the fingers must lift and touch again to paint).
    private func endStrokes() {
        for id in pointers.active.keys {
            _ = tracker.handle(PointerEvent(id: id, phase: .cancelled, location: Vec2(0, 0), timestamp: clock()))
            queue.forget(pointer: id)
        }
    }

    private func announce(_ announcement: SimulationControl.Announcement) {
        AccessibilityNotification.Announcement(announcement.text).post()
    }

    /// Still capture (feature 022).
    let capture = CaptureModel()

    func captureStill() {
        guard let host else { return }
        capture.capture(host: host, scene: scene, viewSize: host.view.bounds.size)
    }

    func close() {
        capture.removeFile()
        host?.destroy()
        host = nil
    }
}

struct PlaygroundView: View {
    @State private var model: PlaygroundModel?
    @State private var adjusting = false
    @State private var showingCapture = false
    @State private var detent = PresentationDetent.large

    var body: some View {
        ZStack(alignment: .bottom) {
            if let model, let host = model.host {
                RenderSurface(host: host, accessibilityLabel: model.description,
                              accessibilityHint: "Fluid canvas. Swipe to paint with dye; the Add splash button does the same without a gesture.")
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityIdentifier("fap.canvas")
                Button {
                    model.addSplash()
                } label: {
                    Label("Add splash", systemImage: "drop.fill")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Adds a burst of dye and motion at the center")
                .accessibilityIdentifier("fap.splash")
                .padding(.bottom, 24)
            } else if let failure = model?.failure {
                Text(failure)
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityIdentifier("fap.canvas.failure")
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .navigationTitle("Playground")
        .navigationBarTitleDisplayMode(.inline)
        // Painting with rightward drags must not navigate back (iOS 26 content swipe-back); the edge swipe and the
        // back button still leave the screen (VisualCoreUI, feature 020).
        .contentSwipeBackDisabled()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model?.captureStill()
                    showingCapture = true
                } label: {
                    Label("Capture", systemImage: "camera")
                }
                .accessibilityIdentifier("fap.capture")
                .disabled(model?.host == nil)
            }
            // Pause, Step and Reset (feature 023 FR-A02-501): VoiceOver reads each label, value and hint.
            ToolbarItemGroup(placement: .bottomBar) {
                if let model, model.host != nil {
                    Button {
                        model.togglePause()
                    } label: {
                        Label(model.control.pauseLabel, systemImage: model.control.paused ? "play.fill" : "pause.fill")
                    }
                    .accessibilityIdentifier("fap.pause")
                    .accessibilityHint(model.control.paused ? "Continues the simulation" : "Freezes the fluid; the picture stays on screen")
                    Spacer()
                    Button {
                        model.step()
                    } label: {
                        Label("Step", systemImage: "forward.frame.fill")
                    }
                    .accessibilityIdentifier("fap.step")
                    .accessibilityHint(model.control.stepHint)
                    .disabled(!model.control.stepEnabled)
                    Spacer()
                    Button {
                        model.resetCanvas()
                    } label: {
                        Label("Reset canvas", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("fap.reset")
                    .accessibilityHint("Returns the fluid to the starting picture; your settings are kept")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    adjusting = true
                } label: {
                    Label("Adjust", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("fap.adjust")
                .disabled(model?.host == nil)
            }
        }
        .sheet(isPresented: $showingCapture) {
            if let model { CaptureSheet(capture: model.capture) }
        }
        .sheet(isPresented: $adjusting) {
            if let model {
                // Opens large so every control is reachable; medium shows the canvas while tuning. The opaque
                // background keeps text contrast independent of the artwork behind the sheet (feature 021 audit).
                AdjustPanel(model: model)
                    .presentationDetents([.medium, .large], selection: $detent)
                    .presentationBackground(Color(uiColor: .systemGroupedBackground))
            }
        }
        .onAppear {
            if model == nil { model = PlaygroundModel() }
        }
        .onDisappear {
            model?.close()
            model = nil
        }
    }
}

/// The result of a capture: share or save the picture, or read why it failed.
struct CaptureSheet: View {
    let capture: CaptureModel
    @Environment(\.dismiss) private var dismiss
    @State private var detent = PresentationDetent.large

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 20) {
                switch capture.state {
                case .done(let url):
                    if let image = capture.lastImage {
                        Text("Captured \(image.width) × \(image.height) pixels.")
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("fap.capture.message")
                    }
                    ShareLink(item: url) {
                        Label {
                            Text("Share or Save Image").fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("fap.capture.share")
                case .failed(let message):
                    Text(message).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fap.capture.message")
                case .idle:
                    Text("Nothing captured yet.").accessibilityIdentifier("fap.capture.message")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .tint(AccessibleColors.accent)
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("fap.capture.done")
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }
}
