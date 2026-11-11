// PlaygroundView.swift — the fluid canvas screen (feature 019 T-A02-112; feature 020 T-A02-213; FR-A02-106,
// FR-A02-208; contracts/app-splats.md). The screen owns exactly one RenderHost (VisualCore's audited EGL host) and
// destroys it when it goes away; the app creates no EGL context. Touches arrive through `RenderHost.pointerHandler`,
// become evenly spaced samples (VisualCore PointerVelocityTracker) and capped splats (SplatQueue), drained once per
// rendered frame. "Add splash" is the control alternative to swiping. Touch paths are never recorded or stored.
import FluidArtPlaygroundCore
import QuartzCore
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreUI

@MainActor
@Observable
final class PlaygroundModel {
    let scene: FluidFieldsScene
    private(set) var host: RenderHost?
    private(set) var failure: String?
    private(set) var splashes = 0
    private(set) var queue: SplatQueue
    /// The live tuning (feature 021): every change reaches the scene on the next frame without a rebuild.
    var configuration: FluidConfiguration {
        didSet { scene.update(configuration: configuration) }
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

    init(configuration: FluidConfiguration = FluidConfiguration(), maxEdge: Int = 512) {
        scene = FluidFieldsScene(configuration: configuration, maxEdge: maxEdge)
        queue = SplatQueue(configuration: configuration)
        self.configuration = scene.configuration
        scene.splatSource = { [weak self] in self?.drain() ?? [] }
        do {
            let host = try RenderHost(scene: scene)
            host.pointerHandler = { [weak self] event in self?.handle(event) }
            self.host = host
        } catch {
            failure = "The graphics view could not start: \(error)"
        }
        // Setup ran inside RenderHost.init and may have capped the grid by the device; forces convert with the grid
        // the fields really use (feature 020 T-A02-216).
        queue = SplatQueue(configuration: scene.configuration)
        self.configuration = scene.configuration
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

    /// One touch event from the canvas: resampled by the tracker, converted and queued.
    func handle(_ event: PointerEvent) {
        guard let size = host?.view.bounds.size else { return }
        if tracker.activeCount == 0, abs(tracker.spacing - spacing) > 1e-9 {
            tracker = PointerVelocityTracker(spacing: spacing)
        }
        if event.phase == .cancelled { queue.forget(pointer: event.id) }
        let samples = tracker.handle(event)
        queue.add(samples, viewSize: SIMD2(Double(size.width), Double(size.height)))
    }

    /// The control alternative to swiping: one deterministic splash, announced to VoiceOver.
    func addSplash() {
        queue.addSplash()
        splashes += 1
        AccessibilityNotification.Announcement("Splash added").post()
    }

    /// Called once per stepped frame: decide the tier, apply its iterations to the scene and drain the queue under its
    /// splat cap. The queue itself is never cleared by a tier change.
    private func drain() -> [Splat] {
        let state = deviceState()
        let decided = policy.decide(thermal: state.thermal, lowPower: state.lowPower, now: clock())
        if decided != tier {
            tier = decided
            tierName = FluidQuality.name(decided)
        }
        let parameters = FluidQuality.parameters(tier: tier, configuration: configuration)
        scene.qualityIterations = parameters.iterations
        return queue.drain(max: parameters.splatCap)
    }

    /// The spoken canvas value.
    var description: String {
        FluidCanvasDescription.text(configuration: scene.configuration, storage: scene.precision ?? .unorm8,
                                    paused: scene.paused || host?.state != .active, splashes: splashes)
    }

    func close() {
        host?.destroy()
        host = nil
    }
}

struct PlaygroundView: View {
    @State private var model: PlaygroundModel?
    @State private var adjusting = false
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
                    adjusting = true
                } label: {
                    Label("Adjust", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("fap.adjust")
                .disabled(model?.host == nil)
            }
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
