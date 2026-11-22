// FFSupport — feature 379 (R02-G08-09) T-R02G0809-004 (FR-R02G0809-002; SC-R02G0809-001; clarifications Q1, Q2):
// helpers of the interface tests of Faceted Forge (R02-G08) inside the one app, modelled on `AESupport` (feature 369).
// Every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are
// registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the welcome and opens the
// experience directly with `-openExperience r02-g08.faceted-forge`; a relaunch (`FF.reopen`) backgrounds the app first
// (its save point), terminates it and starts again without the reset, so the stored progress (solved levels, stars,
// the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`FacetedForgePresenter.describe`):
// "Faceted Forge level n. ", "c of b cuts spent. Target: …", the pieces, "Next cut: piece p, direction <name>, depth
// d. " (or "The cut plane misses piece …") and, when won, "The pieces match the target." followed by " Stars: s of 3."
// when the level has stars in the progress. The controls are found by the identifiers of Clarification Q1
// (`port.identifier(name)`, that is `experience.r02-g08.faceted-forge.<name>`): the buttons `cut` (value "<Piece>,
// direction <name>, depth d"), `undo`, `redo`, `next-level`, `depth-down`, `depth-up`, `reset-view`, `hint`,
// `dismiss-tutorial`, `failure-undo`, `retry`, `campaign`, `daily`, `practice` (value "selected" for the current mode,
// else ""), `play-level`, `replay` (when the level has a verified stored solution, not during replay), `replay-step`
// (value "Cut k of n") and `replay-stop`; the steppers `piece-picker` (value `mirror.pieceLabel`, the capitalized piece
// name "Piece k: …"; wraps over the pieces; the depth moves to the middle crossing depth), `direction-picker` (value
// "direction <name>"; wraps over the 13 directions; the depth moves to the middle crossing depth), `depth-picker`
// (value "depth d" or "the plane misses this piece"; steps over the depths whose plane crosses the chosen piece and
// stops at their ends) and `level-picker` (value "Level n, band b" plus ", k stars" when won; never past the open
// frontier or below 1) — all presentation only; the toggle `sound` and the element `summary` (the "Crystal" element).
// The controls sit below the canvas in a scroll view; a control is scrolled into view before it is used, with slow
// drags near the left edge. Everything lives in the namespace `FF`, so that nothing collides with the shared helpers
// of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified cuts and helpers of the R02-G08 interface tests.
enum FF {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g08.faceted-forge"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g08.faceted-forge."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Faceted Forge.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Faceted Forge.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most presses one stepper makes to reach a value (the depth range −24 … 24 has 49 depths; level 1 needs at
    /// most a handful).
    static let maxPresses = 30

    /// One cut: piece `piece` (0-based, canonical order of the play before the cut), direction `direction` (0 … 12,
    /// an index of ``directionNames``) and depth `depth` (−24 … 24).
    struct Cut: Equatable {
        let piece: Int
        let direction: Int
        let depth: Int
    }

    /// The preview choice of the panel: piece, direction and depth, the same three numbers as a cut.
    typealias Choice = Cut

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-22 from the stored witness
    // `docs/games/faceted-forge/levels/001.witness.json`; an app unit test checks them against the Core,
    // `FacetedForgeExperienceCore.certifiedActions(1)` and `FacetedForgePreviewChoice.initial` of level 1's fresh
    // play): the crystal is the cube −5 ≤ x, y, z ≤ 5 (six planes: directions 0, 1, 2 at depths ±5), budget 9,
    // certified smallest 3, tutorial on. The witness's actions, encoded `{"cut": {"_0": piece, "_1": direction, "_2":
    // depth}}` (`FacetedForgeAction.cut(Int, Int, Int)`), are cut(0, 3, −3), cut(0, 3, 1), cut(1, 5, −5): direction 3
    // is x+y and 5 is x+z (`FacetedForgeDirection.all`). Three cuts equal the smallest, so three stars
    // (`FacetedForgeProgress.stars`); the stored trace holds the three cuts.
    //
    // The starting choice: `FacetedForgePreviewChoice.initial(play)` is piece 0, direction `facingDirection` (2, z) and
    // the middle of `FacetedForgeSolver.crossingDepths(pieces[0], direction: 2)`. Before the first cut piece 0 is the
    // whole cube, whose z values run from −5 to 5; the crossing depths are the integers strictly between, −4 … 4
    // (nine), and the middle one (index 9 / 2 = 4) is 0. So the panel opens on piece 0, direction z, depth 0. After a
    // cut the presenter clamps the choice to the new pieces (`FacetedForgeMirror.follow`: the same piece index and
    // direction, the nearest crossing depth), and a piece or direction step moves the depth to the middle crossing
    // depth, so the tests never assume a choice: before each cut every stepper is read and stepped from its current
    // value.

    /// Level 1's certified cuts, in the order of the witness.
    static let levelOneCuts: [Cut] = [
        Cut(piece: 0, direction: 3, depth: -3),
        Cut(piece: 0, direction: 3, depth: 1),
        Cut(piece: 1, direction: 5, depth: -5),
    ]
    /// The panel's choice when level 1 opens (`FacetedForgePreviewChoice.initial`; derived above).
    static let levelOneInitialChoice = Choice(piece: 0, direction: 2, depth: 0)
    /// The 13 direction names (`FacetedForgeDirection.name`, "−" is U+2212), by index.
    static let directionNames: [String] = [
        "x", "y", "z", "x+y", "x\u{2212}y", "x+z", "x\u{2212}z", "y+z", "y\u{2212}z",
        "x+y+z", "x+y\u{2212}z", "x\u{2212}y+z", "\u{2212}x+y+z",
    ]
    /// Level 1's cut budget.
    static let levelOneBudget = 9
    /// Level 1's certified smallest cut count.
    static let levelOneSmallest = 3
    /// The length of the trace stored by the certified win (the three cuts).
    static let levelOneTraceLength = 3

    /// The canvas phrase of a won level.
    static let won = "The pieces match the target."
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "Stars: 3 of 3."
    /// The level picker's value of level 1 once it is won with three stars (band 1: levels 1 … 20).
    static let levelOneThreeStars = "Level 1, band 1, 3 stars"

    /// The canvas phrase of `cuts` cuts spent of level 1's budget.
    static func spent(_ cuts: Int) -> String { ". \(cuts) of \(levelOneBudget) cuts spent." }

    /// The canvas phrase of the next cut of `choice` (when the plane crosses the chosen piece).
    static func nextCut(_ choice: Choice) -> String {
        "Next cut: piece \(choice.piece + 1), direction \(directionNames[choice.direction]), depth \(choice.depth)."
    }

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name`, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The value of the control `name` as text, or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// The live canvas of the session; its label is the presenter's description.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement {
        element(app, VC.canvas)
    }

    /// The canvas description, or "" when the canvas is not there.
    @MainActor
    static func description(_ app: XCUIApplication) -> String {
        let c = canvas(app)
        return c.exists ? c.label : ""
    }

    /// Launches the app with `arguments` and waits until Faceted Forge runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = FF.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Faceted Forge again over the same storage
    /// (``relaunch``, no reset).
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        // Backgrounding is the app's save point for the open experience's state (as PersistenceUITests ends a run);
        // a bare terminate would lose the win.
        XCUIDevice.shared.press(.home)
        usleep(1_000_000)
        app.terminate()
        let second = launchApp(arguments: FF.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        // "contains", not "hasPrefix": a drag preview puts "The cut plane would …" first.
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Faceted Forge level") },
                      "the canvas is labelled with a level: \(description(app))", file: file, line: line)
    }

    /// Taps `dismiss-tutorial` when the tutorial shows it (a fresh start of level 1 does); nothing otherwise.
    @MainActor
    static func dismissTutorialIfShown(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let dismiss = control(app, "dismiss-tutorial")
        guard dismiss.waitForExistence(timeout: 2) else { return }
        guard reveal(app, dismiss, file: file, line: line) else { return }
        dismiss.tap()
        XCTAssertTrue(waitUntilGone(dismiss, timeout: shortWait), "the tutorial is dismissed", file: file, line: line)
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// Whether `target` lies wholly inside the visible controls (or, when taller than them, covers their middle) and
    /// can be tapped.
    @MainActor
    static func isShown(_ app: XCUIApplication, _ target: XCUIElement) -> Bool {
        guard target.exists, target.isHittable else { return false }
        let list = controlsList(app)
        guard list.exists else { return true }
        let visible = list.frame.insetBy(dx: 0, dy: -1), frame = target.frame
        if frame.height >= visible.height { return frame.minY <= visible.midY && frame.maxY >= visible.midY }
        return frame.minY >= visible.minY && frame.maxY <= visible.maxY
    }

    /// Whether `target`'s whole frame lies inside the controls list's visible frame (or the window when there is no
    /// list), whatever its hittability says.
    @MainActor
    static func insideList(_ app: XCUIApplication, _ target: XCUIElement) -> Bool {
        let list = controlsList(app)
        let visible = (list.exists ? list.frame : app.windows.firstMatch.frame).insetBy(dx: 0, dy: -1)
        let frame = target.frame
        return !frame.isEmpty && frame.minY >= visible.minY && frame.maxY <= visible.maxY
    }

    /// One slow drag on the controls near their left edge, with a hold at the end, so the list moves by the drag's
    /// length without a fling. Positive `distance` moves the finger up (shows the controls further down); it is cut to
    /// 85 % of the list's height and raised to 40 points, beyond the scroll view's touch slop.
    @MainActor
    static func drag(_ app: XCUIApplication, by distance: CGFloat) {
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        let height = max(area.frame.height, 1)
        let size = min(max(abs(distance), 40), height * 0.85)
        let half = size / 2 / height
        let up = distance > 0
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5 + (up ? half : -half)))
            .withOffset(CGVector(dx: 8, dy: 0))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5 + (up ? -half : half)))
            .withOffset(CGVector(dx: 8, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// Scrolls the controls until `target` is shown, at most ``maxDrags`` drags. Fails the test at the caller's line
    /// when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var drags = 0
        // A drag that leaves the target where it was means the list is at its end: a hittable target is then as far
        // in view as it can be.
        var stuck = false
        while drags < maxDrags, target.exists, !isShown(app, target) {
            let list = controlsList(app)
            let middle = list.exists ? list.frame.midY : app.windows.firstMatch.frame.midY
            let before = target.frame
            var distance = before.midY - middle
            if abs(distance) < 1 { distance = 40 }
            drag(app, by: distance)
            drags += 1
            if target.frame == before {
                stuck = true
                break
            }
        }
        let found = isShown(app, target) || (stuck && target.exists && target.isHittable)
            || (target.exists && insideList(app, target))
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Waits for the control `name`, scrolls it into view and returns it, or nil when it is not there.
    @MainActor
    static func shown(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIElement? {
        let target = control(app, name)
        // An element already present skips the bounded wait, whose first check costs about a second.
        guard target.exists || waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return nil }
        return target
    }

    /// Waits for the control `name`, scrolls it into view and taps it; true when it was tapped.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard let target = shown(app, name, file: file, line: line) else { return false }
        target.tap()
        return true
    }

    /// The stepper `name` (`piece-picker`, `direction-picker`, `depth-picker` or `level-picker`): the system stepper
    /// with the identifier when there is one, else the control of any type.
    @MainActor
    static func stepper(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let found = app.steppers.matching(identifier: id(name)).firstMatch
        return found.exists ? found : control(app, name)
    }

    /// The increment (`up`) or decrement button of the stepper `name`: the inner button whose label or identifier
    /// names it, else a button with the suffixed identifier, else nil (the caller taps the end of the row).
    @MainActor
    static func stepperButton(_ app: XCUIApplication, _ name: String, up: Bool) -> XCUIElement? {
        let word = up ? "Increment" : "Decrement"
        let inner = stepper(app, name).buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", word, word)).firstMatch
        if inner.exists { return inner }
        let suffixed = element(app, id(name) + "-" + word)
        return suffixed.exists ? suffixed : nil
    }

    /// Presses the increment (`up`) or decrement button of the stepper `name` once and waits briefly until its value
    /// changes; returns the value after the press.
    @MainActor
    @discardableResult
    static func press(_ app: XCUIApplication, _ name: String, up: Bool) -> String {
        let control = stepper(app, name)
        let before = control.value as? String ?? ""
        // A restored panel can report a visible button as not hittable (nested scroll views right after a relaunch);
        // a coordinate tap still reaches it, and an unchanged value fails the caller.
        if let button = stepperButton(app, name, up: up) {
            if button.isHittable { button.tap() } else {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            control.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
        }
        _ = waitForValue(control, timeout: 2) { $0 != before }
        return control.value as? String ?? ""
    }

    /// Makes sure both buttons of the stepper `name` can be tapped, scrolling the stepper into view when they cannot.
    @MainActor
    private static func ready(_ app: XCUIApplication, _ name: String, file: StaticString, line: UInt) -> Bool {
        let control = stepper(app, name)
        guard control.exists || waitFor(control, timeout: shortWait, "\(name) is there", file: file, line: line)
        else { return false }
        // No scrolling when both stepper buttons can already be tapped (the stepper's own centre can be covered while
        // its buttons are not). Right after a relaunch the restored panel is still being laid out, so the buttons get a
        // bounded moment (at most 5 s, checked every 0.25 s) to become tappable before any scrolling.
        var hittable = false
        var checks = 0
        while !hittable, checks < 20 {
            hittable = (stepperButton(app, name, up: true)?.isHittable ?? false)
                && (stepperButton(app, name, up: false)?.isHittable ?? false)
            if !hittable { usleep(250_000) }
            checks += 1
        }
        return hittable || reveal(app, control, file: file, line: line)
    }

    /// The 0-based piece of a piece picker value "Piece k: …" (`mirror.pieceLabel`, capitalized), or nil.
    static func pickedPiece(_ text: String) -> Int? {
        guard text.hasPrefix("Piece ") else { return nil }
        let rest = text.dropFirst("Piece ".count)
        guard let colon = rest.firstIndex(of: ":"), let k = Int(rest[rest.startIndex..<colon]) else { return nil }
        return k - 1
    }

    /// The direction index of a direction picker value "direction <name>", or nil.
    static func pickedDirection(_ text: String) -> Int? {
        guard text.hasPrefix("direction ") else { return nil }
        return directionNames.firstIndex(of: String(text.dropFirst("direction ".count)))
    }

    /// The depth of a depth picker value "depth d", or nil (also for "the plane misses this piece").
    static func pickedDepth(_ text: String) -> Int? {
        guard text.hasPrefix("depth ") else { return nil }
        return Int(text.dropFirst("depth ".count))
    }

    /// The panel's current choice read from the three steppers, or nil when one cannot be read.
    @MainActor
    static func currentChoice(_ app: XCUIApplication) -> Choice? {
        guard let piece = pickedPiece(stepper(app, "piece-picker").value as? String ?? ""),
              let direction = pickedDirection(stepper(app, "direction-picker").value as? String ?? ""),
              let depth = pickedDepth(stepper(app, "depth-picker").value as? String ?? "") else { return nil }
        return Choice(piece: piece, direction: direction, depth: depth)
    }

    /// Steps the stepper `name` from its current value (read with `parse`) to `target`, at most ``maxPresses``
    /// presses. A wrapping stepper (`count` values, 0-based) goes the shorter way round; a non-wrapping one (`count`
    /// nil) goes up when it is below the target, else down, and stops when a press leaves its value unchanged (an end
    /// of its range). True when it shows the target.
    @MainActor
    @discardableResult
    static func step(_ app: XCUIApplication, _ name: String, to target: Int, count: Int?,
                     parse: (String) -> Int?, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard ready(app, name, file: file, line: line) else { return false }
        let control = stepper(app, name)
        var current = control.value as? String ?? ""
        var presses = 0
        while let at = parse(current), at != target, presses < maxPresses {
            let up: Bool
            if let count, count > 0 {
                let forward = ((target - at) % count + count) % count
                up = forward <= count - forward
            } else {
                up = at < target
            }
            let after = press(app, name, up: up)
            presses += 1
            if after == current, count == nil { break }   // an end of the depths: it cannot move further
            current = after
        }
        let reached = parse(current) == target
        XCTAssertTrue(reached, "\(name) shows \(target) after \(presses) presses (now \(current))",
                      file: file, line: line)
        return reached
    }

    /// Sets the panel's choice to `cut` with the steppers, each stepped from its current value: the piece first and
    /// the direction next (each moves the depth to its middle crossing depth), then the depth. `pieces` is the number
    /// of pieces of the play (the piece picker wraps over them). True when every stepper shows its value.
    @MainActor
    @discardableResult
    static func choose(_ app: XCUIApplication, _ cut: Cut, pieces: Int,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        step(app, "piece-picker", to: cut.piece, count: pieces, parse: pickedPiece, file: file, line: line)
            && step(app, "direction-picker", to: cut.direction, count: directionNames.count,
                    parse: pickedDirection, file: file, line: line)
            && step(app, "depth-picker", to: cut.depth, count: nil, parse: pickedDepth, file: file, line: line)
    }

    /// The level number of a level picker value "Level n, band b[, k stars]", or nil.
    static func pickedLevel(_ text: String) -> Int? {
        guard text.hasPrefix("Level ") else { return nil }
        let rest = text.dropFirst("Level ".count)
        guard let comma = rest.firstIndex(of: ",") else { return nil }
        return Int(rest[rest.startIndex..<comma])
    }

    /// Steps the level picker to `level` (it holds open levels only), at most four presses; returns its value then.
    @MainActor
    @discardableResult
    static func pickLevel(_ app: XCUIApplication, _ level: Int, file: StaticString = #filePath, line: UInt = #line)
        -> String {
        guard ready(app, "level-picker", file: file, line: line) else { return "" }
        let control = stepper(app, "level-picker")
        var current = control.value as? String ?? ""
        var presses = 0
        while let picked = pickedLevel(current), picked != level, presses < 4 {
            let after = press(app, "level-picker", up: picked < level)
            presses += 1
            if after == current { break }   // the frontier or level 1: the picker cannot move further
            current = after
        }
        return current
    }

    /// Plays level 1's certified cuts with the panel: before each cut the piece, direction and depth steppers are
    /// stepped from their current values to the cut's, the canvas must name that next cut, and Cut is tapped; after
    /// every cut the canvas must report one more cut spent. True when every control was used and showed what it
    /// should.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for (index, cut) in levelOneCuts.enumerated() {
            // Each cut splits one piece in two, so the play before cut `index` holds `index + 1` pieces.
            guard choose(app, cut, pieces: index + 1, file: file, line: line) else { return false }
            XCTAssertTrue(waitForDescription(app) { $0.contains(nextCut(cut)) },
                          "the canvas names cut \(index + 1): \(description(app))", file: file, line: line)
            guard let button = shown(app, "cut", file: file, line: line) else { return false }
            let words = "direction \(directionNames[cut.direction]), depth \(cut.depth)"
            XCTAssertTrue((button.value as? String ?? "").hasSuffix(words),
                          "Cut shows the choice (\(button.value as? String ?? ""))", file: file, line: line)
            button.tap()
            XCTAssertTrue(waitForDescription(app) { $0.contains(spent(index + 1)) },
                          "cut \(index + 1) is spent: \(description(app))", file: file, line: line)
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified cuts; returns the app after the canvas
    /// reports the pieces match the target with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Faceted Forge level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains(spent(0)),
                      "level 1 starts with no cut spent of its budget: \(description(app))", file: file, line: line)
        XCTAssertEqual(currentChoice(app), levelOneInitialChoice,
                       "the pickers start on piece 1, direction z, depth 0", file: file, line: line)
        XCTAssertTrue(description(app).contains(nextCut(levelOneInitialChoice)),
                      "the canvas names the starting choice: \(description(app))", file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) && $0.contains(threeStars) },
                      "the canvas reports the pieces match the target with three stars: \(description(app))",
                      file: file, line: line)
        return app
    }

    /// The position and length of a replay step value "Cut k of n", or nil.
    static func replayPosition(_ text: String) -> (position: Int, length: Int)? {
        guard text.hasPrefix("Cut ") else { return nil }
        let parts = text.dropFirst("Cut ".count).components(separatedBy: " of ")
        guard parts.count == 2, let p = Int(parts[0]), let n = Int(parts[1]) else { return nil }
        return (p, n)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = FF.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = FF.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = FF.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
