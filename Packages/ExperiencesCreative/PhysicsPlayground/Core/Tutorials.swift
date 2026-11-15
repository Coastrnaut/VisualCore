// Tutorials — feature 085 (A11-P04) T-A11-402 (FR-A11-410, FR-A11-431; clarification 4; research D4; data-model
// "TutorialProgress"). The two tutorials, their step texts and their pure step conditions, and the progress through
// them. The step texts are original content (author "VisualCore project", license "MIT"), listed by `LicenseAudit` with
// the role `tutorial`, one row per tutorial.
//
// Tutorial 0 "Controlling time":
//   0 "Pause the world."          → the world is paused;
//   1 "Step forward one tick."    → the world is paused and its tick is exactly the step's start tick + 1;
//   2 "Choose half speed."        → the time-scale index is 1 (½);
//   3 "Press Reset."              → the caller reports that a reset was just applied (`justReset`).
// Tutorial 1 "Springs and energy":
//   0 "Open the spring chain."    → the origin is preset 2 (spring chain);
//   1 "Show the force arrows."    → force arrows are shown;
//   2 "Let it run for 3 seconds." → the world runs and its tick is at least the step's start tick + 360.
//
// The adapter passes a `TutorialContext` after every applied action and every host step. `Tutorials.advance` then
// completes as many steps in order as hold: each completed step starts the next one with the start tick set to the
// context world's tick (the condition of the next step is checked with that start tick), and completing the last step
// clears the progress. A progress that names no tutorial or step is cleared. Everything is pure and deterministic.
import Foundation

/// What a step condition may look at: the world after the action or step, the experiment's starting world, its
/// origin, the tick at which the current step began, and whether the action just applied was a reset.
public struct TutorialContext: Equatable, Sendable {
    /// The world now.
    public var world: PhysicsWorld
    /// The world the experiment opened with (what reset restores).
    public var startingWorld: PhysicsWorld
    /// Where the experiment came from.
    public var origin: ExperimentOrigin
    /// The tick at which the current step began (``Tutorials/advance(_:context:)`` sets it from the progress).
    public var stepStartTick: Int
    /// True when the action just applied was a reset.
    public var justReset: Bool

    /// Creates a context.
    public init(world: PhysicsWorld, startingWorld: PhysicsWorld, origin: ExperimentOrigin, stepStartTick: Int = 0,
                justReset: Bool = false) {
        self.world = world; self.startingWorld = startingWorld; self.origin = origin
        self.stepStartTick = stepStartTick; self.justReset = justReset
    }
}

/// One step of a tutorial: the text shown and spoken, and the condition that completes it.
public struct TutorialStep: Sendable {
    /// The text shown and spoken.
    public var text: String
    /// True when the step is complete.
    public var condition: @Sendable (TutorialContext) -> Bool

    /// Creates a step.
    public init(text: String, condition: @escaping @Sendable (TutorialContext) -> Bool) {
        self.text = text; self.condition = condition
    }
}

/// A tutorial: an id, a name and its steps in order.
public struct Tutorial: Sendable {
    /// The tutorial id (0 or 1; the value of the `tutorial.start` action).
    public var id: Int
    /// The kebab-case content id used in the license audit.
    public var contentId: String
    /// The display name.
    public var name: String
    /// The steps in order.
    public var steps: [TutorialStep]
    /// The author of the texts ("VisualCore project").
    public var author: String { MaterialCatalog.projectAuthor }
    /// The license of the texts ("MIT").
    public var license: String { "MIT" }
}

/// The progress through a running tutorial.
public struct TutorialProgress: Codable, Equatable, Sendable {
    /// The tutorial id, 0…1.
    public var tutorial: Int
    /// The current step, 0…n − 1.
    public var step: Int
    /// The world tick at which the current step began.
    public var startTick: Int

    /// Creates a progress record (no validation; ``isValid`` checks it).
    public init(tutorial: Int, step: Int, startTick: Int) {
        self.tutorial = tutorial; self.step = step; self.startTick = startTick
    }

    /// True when the tutorial and the step exist and the start tick is not negative.
    public var isValid: Bool {
        guard let tutorial = Tutorials.tutorial(id: self.tutorial) else { return false }
        return tutorial.steps.indices.contains(step) && startTick >= 0
    }
}

/// The two tutorials and the progress rules.
public enum Tutorials {
    /// The ticks the "Let it run" step needs (3 s at 120 ticks per second).
    public static let runTicks = 360

    /// The tutorials, by id.
    public static let all: [Tutorial] = [
        Tutorial(id: 0, contentId: "controlling-time", name: "Controlling time", steps: [
            TutorialStep(text: "Pause the world.") { $0.world.paused },
            TutorialStep(text: "Step forward one tick.") { $0.world.paused && $0.world.tick == $0.stepStartTick + 1 },
            TutorialStep(text: "Choose half speed.") { $0.world.timeScaleIndex == 1 },
            TutorialStep(text: "Press Reset.") { $0.justReset },
        ]),
        Tutorial(id: 1, contentId: "springs-and-energy", name: "Springs and energy", steps: [
            TutorialStep(text: "Open the spring chain.") { $0.origin == .preset(PresetID.springChain.rawValue) },
            TutorialStep(text: "Show the force arrows.") { $0.world.showForces },
            TutorialStep(text: "Let it run for 3 seconds.") {
                !$0.world.paused && $0.world.tick >= $0.stepStartTick + runTicks
            },
        ]),
    ]

    /// The tutorial with id `id`, nil when there is none.
    public static func tutorial(id: Int) -> Tutorial? { all.indices.contains(id) ? all[id] : nil }

    /// The progress of tutorial `id` at step 0, beginning at `tick`; nil when there is no such tutorial.
    public static func start(_ id: Int, tick: Int) -> TutorialProgress? {
        tutorial(id: id) == nil ? nil : TutorialProgress(tutorial: id, step: 0, startTick: tick)
    }

    /// The text of the current step of `progress`, nil when there is none.
    public static func text(_ progress: TutorialProgress?) -> String? {
        guard let progress, progress.isValid else { return nil }
        return all[progress.tutorial].steps[progress.step].text
    }

    /// Completes as many steps of `progress` as hold in `context`, in order: the current step's condition is checked
    /// with `stepStartTick` = the progress's start tick; a completed step starts the next one at `context.world.tick`;
    /// completing the last step sets `progress` to nil. An invalid progress becomes nil; nil stays nil. Returns the
    /// number of steps completed.
    @discardableResult
    public static func advance(_ progress: inout TutorialProgress?, context: TutorialContext) -> Int {
        guard var current = progress else { return 0 }
        guard current.isValid else { progress = nil; return 0 }
        let steps = all[current.tutorial].steps
        var context = context, completed = 0
        while true {
            context.stepStartTick = current.startTick
            guard steps[current.step].condition(context) else { break }
            completed += 1
            if current.step + 1 == steps.count { progress = nil; return completed }
            current.step += 1
            current.startTick = context.world.tick
        }
        progress = current
        return completed
    }
}
